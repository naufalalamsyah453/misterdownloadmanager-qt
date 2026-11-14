//! The download list's state, with no Qt in it: every download is an `Entry` that owns an
//! `mdm_engine::Download` while it runs. The Qt model (`model.rs`) only reads and changes this.

use std::path::{Path, PathBuf};
use std::time::{Instant, SystemTime};

use mdm_engine::download::State as EngineState;
use mdm_engine::{Destination, Download, Options, Request, Snapshot};
use reqwest::header::HeaderMap;
use url::Url;

/// What the list shows for a download. `Paused` is a cancelled engine download whose state file
/// is still on disk, so it can resume.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Status {
    Queued,
    Connecting,
    Downloading,
    Finishing,
    Paused,
    Complete,
    Failed,
}

impl Status {
    pub fn key(self) -> &'static str {
        match self {
            Status::Queued => "queued",
            Status::Connecting => "connecting",
            Status::Downloading => "downloading",
            Status::Finishing => "finishing",
            Status::Paused => "paused",
            Status::Complete => "complete",
            Status::Failed => "failed",
        }
    }

    pub fn is_active(self) -> bool {
        matches!(
            self,
            Status::Queued | Status::Connecting | Status::Downloading | Status::Finishing
        )
    }
}

/// The sidebar's categories, by file extension.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Category {
    Compressed,
    Documents,
    Music,
    Programs,
    Video,
    Other,
}

impl Category {
    pub fn key(self) -> &'static str {
        match self {
            Category::Compressed => "compressed",
            Category::Documents => "documents",
            Category::Music => "music",
            Category::Programs => "programs",
            Category::Video => "video",
            Category::Other => "other",
        }
    }

    pub fn of(name: &str) -> Category {
        let ext = Path::new(name)
            .extension()
            .and_then(|e| e.to_str())
            .map(str::to_ascii_lowercase)
            .unwrap_or_default();
        match ext.as_str() {
            "zip" | "7z" | "rar" | "tar" | "gz" | "xz" | "bz2" | "zst" => Category::Compressed,
            "pdf" | "doc" | "docx" | "xls" | "xlsx" | "ppt" | "pptx" | "txt" | "epub" | "odt" => {
                Category::Documents
            }
            "mp3" | "flac" | "wav" | "ogg" | "opus" | "m4a" | "aac" => Category::Music,
            "exe" | "msi" | "deb" | "rpm" | "appimage" | "dmg" | "pkg" | "apk" => {
                Category::Programs
            }
            "mp4" | "mkv" | "avi" | "mov" | "webm" | "wmv" | "flv" | "m4v" => Category::Video,
            _ => Category::Other,
        }
    }
}

pub struct Entry {
    pub id: u64,
    pub url: Url,
    pub dir: PathBuf,
    /// The saved file, once the engine knows it.
    pub file: Option<PathBuf>,
    pub name: String,
    pub size: Option<u64>,
    pub downloaded: u64,
    pub speed: u64,
    pub status: Status,
    pub error: Option<String>,
    pub added: SystemTime,
    download: Option<Download>,
    sample: Option<(Instant, u64)>,
}

impl Entry {
    pub fn category(&self) -> Category {
        Category::of(&self.name)
    }

    /// 0 to 1, or -1 while the size isn't known.
    pub fn progress(&self) -> f64 {
        match self.size {
            Some(size) if size > 0 => (self.downloaded as f64 / size as f64).clamp(0.0, 1.0),
            _ if self.status == Status::Complete => 1.0,
            _ => -1.0,
        }
    }

    /// Seconds left at the current speed, when both are known.
    pub fn eta(&self) -> Option<u64> {
        let size = self.size?;
        (self.speed > 0 && self.status == Status::Downloading)
            .then(|| size.saturating_sub(self.downloaded) / self.speed)
    }
}

/// A change `Manager::poll` found, so the model can say which rows changed.
pub enum Change {
    Row(usize),
}

pub struct Manager {
    rt: tokio::runtime::Runtime,
    pub entries: Vec<Entry>,
    next_id: u64,
    pub default_dir: PathBuf,
}

impl Manager {
    pub fn new() -> Manager {
        let rt = tokio::runtime::Builder::new_multi_thread()
            .worker_threads(2)
            .enable_all()
            .thread_name("mdm-engine")
            .build()
            .expect("tokio runtime");
        let default_dir = dirs_download();
        Manager {
            rt,
            entries: Vec::new(),
            next_id: 1,
            default_dir,
        }
    }

    /// Adds a download and starts it. Returns the new row, or why the address was refused.
    pub fn add(&mut self, url: &str, dir: Option<PathBuf>) -> Result<usize, String> {
        let url = Url::parse(url.trim()).map_err(|e| e.to_string())?;
        if !mdm_engine::supported(&url) {
            return Err(format!("not a downloadable address: {url}"));
        }
        let dir = dir.unwrap_or_else(|| self.default_dir.clone());
        let name = mdm_engine::naming::address_name(&url);
        let mut e = Entry {
            id: self.next_id,
            url,
            dir,
            file: None,
            name,
            size: None,
            downloaded: 0,
            speed: 0,
            status: Status::Queued,
            error: None,
            added: SystemTime::now(),
            download: None,
            sample: None,
        };
        self.next_id += 1;
        self.start(&mut e);
        self.entries.push(e);
        Ok(self.entries.len() - 1)
    }

    fn start(&self, e: &mut Entry) {
        let _guard = self.rt.enter();
        let req = Request {
            url: e.url.clone(),
            headers: HeaderMap::new(),
            dest: Destination::Dir(e.dir.clone()),
        };
        e.download = Some(Download::start(req, Options::default()));
        e.status = Status::Connecting;
        e.error = None;
        e.sample = None;
    }

    pub fn pause(&mut self, row: usize) {
        if let Some(e) = self.entries.get_mut(row)
            && e.status.is_active()
            && let Some(d) = &e.download
        {
            d.cancel();
            // `poll` sees the engine say Cancelled and settles on Paused.
        }
    }

    pub fn resume(&mut self, row: usize) -> Result<(), String> {
        let Some(e) = self.entries.get(row) else {
            return Ok(());
        };
        if !matches!(e.status, Status::Paused | Status::Failed) {
            return Ok(());
        }
        let _guard = self.rt.enter();
        let state_file = e.file.as_deref().map(mdm_engine::state::state_path);
        let started = match state_file {
            Some(f) if f.exists() => {
                Download::resume(f, HeaderMap::new(), Options::default()).map_err(|e| e.to_string())
            }
            _ => Ok(Download::start(
                Request {
                    url: e.url.clone(),
                    headers: HeaderMap::new(),
                    dest: Destination::Dir(e.dir.clone()),
                },
                Options::default(),
            )),
        }?;
        let e = &mut self.entries[row];
        e.download = Some(started);
        e.status = Status::Connecting;
        e.error = None;
        e.sample = None;
        Ok(())
    }

    /// Removes the row; with `delete_files`, its file and half-done parts too.
    pub fn remove(&mut self, row: usize, delete_files: bool) {
        if row >= self.entries.len() {
            return;
        }
        let e = self.entries.remove(row);
        if let Some(d) = &e.download {
            d.cancel();
        }
        if delete_files && let Some(file) = &e.file {
            let _ = std::fs::remove_file(mdm_engine::state::state_path(file));
            let _ = std::fs::remove_file(mdm_engine::naming::part_path(file));
            if e.status != Status::Complete || delete_files {
                let _ = std::fs::remove_file(file);
            }
        }
    }

    /// Reads every running download's snapshot into its entry. Returns the rows that changed.
    pub fn poll(&mut self) -> Vec<Change> {
        let mut changed = Vec::new();
        for (row, e) in self.entries.iter_mut().enumerate() {
            let Some(d) = &e.download else { continue };
            let snap = d.snapshot();
            if apply(e, &snap) {
                changed.push(Change::Row(row));
            }
            if matches!(
                snap.state,
                EngineState::Done | EngineState::Failed | EngineState::Cancelled
            ) {
                e.download = None;
                e.speed = 0;
                e.sample = None;
                changed.push(Change::Row(row));
            }
        }
        changed
    }

    pub fn active_speed(&self) -> u64 {
        self.entries
            .iter()
            .filter(|e| e.status == Status::Downloading)
            .map(|e| e.speed)
            .sum()
    }
}

/// Copies a snapshot into an entry, working out its speed from the bytes between two polls.
fn apply(e: &mut Entry, s: &Snapshot) -> bool {
    let before = (e.status, e.downloaded, e.size, e.speed);
    if let Some(file) = &s.file {
        e.name = file
            .file_name()
            .map(|n| n.to_string_lossy().into_owned())
            .unwrap_or_else(|| e.name.clone());
        e.file = Some(file.clone());
    }
    e.size = s.size.or(e.size);
    e.downloaded = s.downloaded;
    e.status = match s.state {
        EngineState::Probing => Status::Connecting,
        EngineState::Downloading => Status::Downloading,
        EngineState::Verifying | EngineState::Merging | EngineState::Completing => {
            Status::Finishing
        }
        EngineState::Done => Status::Complete,
        EngineState::Failed => Status::Failed,
        EngineState::Cancelled => Status::Paused,
    };
    if s.state == EngineState::Failed {
        e.error = s.error.clone();
    }
    let now = Instant::now();
    match e.sample {
        Some((t, bytes)) if now.duration_since(t).as_millis() >= 500 => {
            let secs = now.duration_since(t).as_secs_f64();
            let rate = (s.downloaded.saturating_sub(bytes)) as f64 / secs;
            // Smooth over polls so the number doesn't jump.
            e.speed = ((e.speed as f64) * 0.5 + rate * 0.5) as u64;
            e.sample = Some((now, s.downloaded));
        }
        None => e.sample = Some((now, s.downloaded)),
        _ => {}
    }
    before != (e.status, e.downloaded, e.size, e.speed)
}

fn dirs_download() -> PathBuf {
    std::env::var_os("XDG_DOWNLOAD_DIR")
        .map(PathBuf::from)
        .or_else(|| std::env::var_os("HOME").map(|h| PathBuf::from(h).join("Downloads")))
        .unwrap_or_else(|| PathBuf::from("."))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn categories_by_extension() {
        assert_eq!(Category::of("a.ZIP"), Category::Compressed);
        assert_eq!(Category::of("movie.mkv"), Category::Video);
        assert_eq!(Category::of("song.flac"), Category::Music);
        assert_eq!(Category::of("setup.exe"), Category::Programs);
        assert_eq!(Category::of("README"), Category::Other);
    }

    #[test]
    fn refuses_non_http_addresses() {
        let mut m = Manager::new();
        assert!(m.add("not a url", None).is_err());
        assert!(m.add("mailto:a@b.c", None).is_err());
    }

    /// The whole path the window uses: add, poll until done, pause and resume, check the bytes.
    #[test]
    fn downloads_pauses_and_resumes_against_the_lab_server() {
        use mdm_labserver::{Config, Faults, LabServer, content};
        use std::time::Duration;

        let mut m = Manager::new();
        let server = m
            .rt
            .block_on(LabServer::start(Config {
                faults: Faults::parse("rate=1M").unwrap(),
                ..Config::default()
            }))
            .unwrap();
        let dir = tempfile::tempdir().unwrap();
        let row = m
            .add(&server.url("/gen/4M/a.bin?seed=7"), Some(dir.path().to_owned()))
            .unwrap();

        let wait_for = |m: &mut Manager, want: &dyn Fn(&Entry) -> bool| {
            let end = Instant::now() + Duration::from_secs(60);
            while Instant::now() < end {
                m.poll();
                if want(&m.entries[row]) {
                    return;
                }
                std::thread::sleep(Duration::from_millis(50));
            }
            panic!("timed out; status {:?}", m.entries[row].status);
        };

        wait_for(&mut m, &|e| e.downloaded > 0 && e.status == Status::Downloading);
        m.pause(row);
        wait_for(&mut m, &|e| e.status == Status::Paused);
        let kept = m.entries[row].downloaded;
        assert!(kept < 4 << 20, "paused before the end");

        m.resume(row).unwrap();
        wait_for(&mut m, &|e| e.status == Status::Complete);
        let e = &m.entries[row];
        assert_eq!(e.size, Some(4 << 20));
        let data = std::fs::read(e.file.as_ref().unwrap()).unwrap();
        let mut want = vec![0; data.len()];
        content::fill(7, 0, &mut want);
        assert!(data == want, "content mismatch after resume");
        assert_eq!(e.progress(), 1.0);
    }
}
