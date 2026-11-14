//! The download list as a Qt model: QML's list view reads rows from it and calls its invokables
//! (add, pause, resume, remove, poll). All state lives in `engine::Manager`.

use core::pin::Pin;

use cxx_qt::CxxQtType;
use cxx_qt_lib::{QByteArray, QHash, QHashPair_i32_QByteArray, QModelIndex, QString, QVariant};

use crate::engine::{Change, Manager};

#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!(<QtCore/QAbstractListModel>);
        type QAbstractListModel;

        include!("cxx-qt-lib/qmodelindex.h");
        type QModelIndex = cxx_qt_lib::QModelIndex;
        include!("cxx-qt-lib/qvariant.h");
        type QVariant = cxx_qt_lib::QVariant;
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qhash.h");
        type QHash_i32_QByteArray = cxx_qt_lib::QHash<cxx_qt_lib::QHashPair_i32_QByteArray>;
        include!("cxx-qt-lib/qlist.h");
        type QList_i32 = cxx_qt_lib::QList<i32>;
    }

    unsafe extern "RustQt" {
        #[qobject]
        #[base = QAbstractListModel]
        #[qml_element]
        #[qproperty(i32, count)]
        #[qproperty(i64, total_speed, cxx_name = "totalSpeed")]
        #[qproperty(i32, active, cxx_name = "activeCount")]
        #[qproperty(i32, revision)]
        type DownloadModel = super::DownloadModelRust;
    }

    unsafe extern "RustQt" {
        #[cxx_override]
        #[cxx_name = "rowCount"]
        fn row_count(self: &DownloadModel, parent: &QModelIndex) -> i32;

        #[cxx_override]
        fn data(self: &DownloadModel, index: &QModelIndex, role: i32) -> QVariant;

        #[cxx_override]
        #[cxx_name = "roleNames"]
        fn role_names(self: &DownloadModel) -> QHash_i32_QByteArray;
    }

    unsafe extern "RustQt" {
        #[inherit]
        #[cxx_name = "beginInsertRows"]
        unsafe fn begin_insert_rows(
            self: Pin<&mut DownloadModel>,
            parent: &QModelIndex,
            first: i32,
            last: i32,
        );
        #[inherit]
        #[cxx_name = "endInsertRows"]
        unsafe fn end_insert_rows(self: Pin<&mut DownloadModel>);
        #[inherit]
        #[cxx_name = "beginRemoveRows"]
        unsafe fn begin_remove_rows(
            self: Pin<&mut DownloadModel>,
            parent: &QModelIndex,
            first: i32,
            last: i32,
        );
        #[inherit]
        #[cxx_name = "endRemoveRows"]
        unsafe fn end_remove_rows(self: Pin<&mut DownloadModel>);
        #[inherit]
        #[qsignal]
        #[cxx_name = "dataChanged"]
        unsafe fn data_changed(
            self: Pin<&mut DownloadModel>,
            top_left: &QModelIndex,
            bottom_right: &QModelIndex,
            roles: &QList_i32,
        );
        #[inherit]
        fn index(
            self: &DownloadModel,
            row: i32,
            column: i32,
            parent: &QModelIndex,
        ) -> QModelIndex;
    }

    unsafe extern "RustQt" {
        /// Adds a download from an address; returns "" or why it was refused.
        #[qinvokable]
        fn add(self: Pin<&mut DownloadModel>, url: &QString) -> QString;
        #[qinvokable]
        fn pause(self: Pin<&mut DownloadModel>, row: i32);
        #[qinvokable]
        fn resume(self: Pin<&mut DownloadModel>, row: i32) -> QString;
        #[qinvokable]
        fn remove(self: Pin<&mut DownloadModel>, row: i32, delete_files: bool);
        /// Called by a QML Timer: reads the engine and tells the view what changed.
        #[qinvokable]
        fn poll(self: Pin<&mut DownloadModel>);
        #[qinvokable]
        #[cxx_name = "folderOf"]
        fn folder_of(self: &DownloadModel, row: i32) -> QString;
        /// How many rows a sidebar entry holds. `revision` only makes a QML binding re-ask
        /// when the list changed.
        #[qinvokable]
        #[cxx_name = "countOf"]
        fn count_of(self: &DownloadModel, key: &QString, revision: i32) -> i32;
        #[qinvokable]
        #[cxx_name = "downloadFolder"]
        fn download_folder(self: &DownloadModel) -> QString;
    }
}

const NAME: i32 = 0x100;
const URL: i32 = 0x101;
const SIZE: i32 = 0x102;
const DONE: i32 = 0x103;
const PROGRESS: i32 = 0x104;
const SPEED: i32 = 0x105;
const ETA: i32 = 0x106;
const STATUS: i32 = 0x107;
const CATEGORY: i32 = 0x108;
const ERROR: i32 = 0x109;
const ADDED: i32 = 0x10a;

pub struct DownloadModelRust {
    count: i32,
    total_speed: i64,
    active: i32,
    revision: i32,
    manager: Manager,
}

impl Default for DownloadModelRust {
    fn default() -> Self {
        Self {
            count: 0,
            total_speed: 0,
            active: 0,
            revision: 0,
            manager: Manager::new(),
        }
    }
}

impl qobject::DownloadModel {
    fn row_count(&self, _parent: &QModelIndex) -> i32 {
        self.rust().manager.entries.len() as i32
    }

    fn data(&self, index: &QModelIndex, role: i32) -> QVariant {
        let Some(e) = usize::try_from(index.row())
            .ok()
            .and_then(|r| self.rust().manager.entries.get(r))
        else {
            return QVariant::default();
        };
        match role {
            NAME => QVariant::from(&QString::from(e.name.as_str())),
            URL => QVariant::from(&QString::from(e.url.as_str())),
            // -1 while unknown, which QML shows as "unknown".
            SIZE => QVariant::from(&e.size.map_or(-1_i64, |s| s as i64)),
            DONE => QVariant::from(&(e.downloaded as i64)),
            PROGRESS => QVariant::from(&e.progress()),
            SPEED => QVariant::from(&(e.speed as i64)),
            ETA => QVariant::from(&e.eta().map_or(-1_i64, |s| s as i64)),
            STATUS => QVariant::from(&QString::from(e.status.key())),
            CATEGORY => QVariant::from(&QString::from(e.category().key())),
            ERROR => QVariant::from(&QString::from(e.error.as_deref().unwrap_or(""))),
            ADDED => QVariant::from(
                &e.added
                    .duration_since(std::time::UNIX_EPOCH)
                    .map_or(0_i64, |d| d.as_secs() as i64),
            ),
            _ => QVariant::default(),
        }
    }

    fn role_names(&self) -> QHash<QHashPair_i32_QByteArray> {
        let mut roles = QHash::<QHashPair_i32_QByteArray>::default();
        for (role, name) in [
            (NAME, "name"),
            (URL, "url"),
            (SIZE, "size"),
            (DONE, "done"),
            (PROGRESS, "progress"),
            (SPEED, "speed"),
            (ETA, "eta"),
            (STATUS, "status"),
            (CATEGORY, "category"),
            (ERROR, "error"),
            (ADDED, "added"),
        ] {
            roles.insert(role, QByteArray::from(name));
        }
        roles
    }

    fn add(mut self: Pin<&mut Self>, url: &QString) -> QString {
        let url = url.to_string();
        let result = self.as_mut().rust_mut().manager.add(&url, None);
        match result {
            Ok(row) => {
                let row = row as i32;
                // The row is already in the list; announce it to the view.
                unsafe {
                    self.as_mut().begin_insert_rows(&QModelIndex::default(), row, row);
                    self.as_mut().end_insert_rows();
                }
                let r = self.revision() + 1;
                self.as_mut().set_revision(r);
                self.as_mut().refresh_counts();
                QString::default()
            }
            Err(why) => QString::from(why.as_str()),
        }
    }

    fn pause(mut self: Pin<&mut Self>, row: i32) {
        if let Ok(r) = usize::try_from(row) {
            self.as_mut().rust_mut().manager.pause(r);
        }
    }

    fn resume(mut self: Pin<&mut Self>, row: i32) -> QString {
        let Ok(r) = usize::try_from(row) else {
            return QString::default();
        };
        match self.as_mut().rust_mut().manager.resume(r) {
            Ok(()) => QString::default(),
            Err(why) => QString::from(why.as_str()),
        }
    }

    fn remove(mut self: Pin<&mut Self>, row: i32, delete_files: bool) {
        let Ok(r) = usize::try_from(row) else { return };
        if r >= self.rust().manager.entries.len() {
            return;
        }
        unsafe {
            self.as_mut().begin_remove_rows(&QModelIndex::default(), row, row);
        }
        self.as_mut().rust_mut().manager.remove(r, delete_files);
        unsafe {
            self.as_mut().end_remove_rows();
        }
        let r = self.revision() + 1;
        self.as_mut().set_revision(r);
        self.as_mut().refresh_counts();
    }

    fn poll(mut self: Pin<&mut Self>) {
        let changes = self.as_mut().rust_mut().manager.poll();
        let changes_empty = changes.is_empty();
        let roles = cxx_qt_lib::QList::<i32>::default();
        for Change::Row(row) in changes {
            let idx = self.index(row as i32, 0, &QModelIndex::default());
            unsafe {
                self.as_mut().data_changed(&idx, &idx, &roles);
            }
        }
        if !changes_empty {
            let r = self.revision() + 1;
            self.as_mut().set_revision(r);
        }
        self.as_mut().refresh_counts();
    }

    fn folder_of(&self, row: i32) -> QString {
        usize::try_from(row)
            .ok()
            .and_then(|r| self.rust().manager.entries.get(r))
            .map(|e| QString::from(e.dir.to_string_lossy().as_ref()))
            .unwrap_or_default()
    }

    fn count_of(&self, key: &QString, _revision: i32) -> i32 {
        use crate::engine::Status;
        let key = key.to_string();
        self.rust()
            .manager
            .entries
            .iter()
            .filter(|e| match key.as_str() {
                "all" => true,
                "active" => e.status.is_active() || e.status == Status::Paused,
                "finished" => e.status == Status::Complete,
                other => e.category().key() == other,
            })
            .count() as i32
    }

    fn download_folder(&self) -> QString {
        QString::from(self.rust().manager.default_dir.to_string_lossy().as_ref())
    }

    fn refresh_counts(mut self: Pin<&mut Self>) {
        let (count, speed, active) = {
            let m = &self.rust().manager;
            (
                m.entries.len() as i32,
                m.active_speed() as i64,
                m.entries.iter().filter(|e| e.status.is_active()).count() as i32,
            )
        };
        self.as_mut().set_count(count);
        self.as_mut().set_total_speed(speed);
        self.as_mut().set_active(active);
    }
}
