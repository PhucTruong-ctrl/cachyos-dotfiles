pragma Singleton

import QtQuick

QtObject {
    id: root
    
    // Using a ListModel instead of raw array to ensure bindings work efficiently.
    // Each object appended gets added to this store.
    property ListModel notifModel: ListModel {}

    function addNotification(notificationData) {
        // Prepend so the newest notification is at the top
        notifModel.insert(0, notificationData)
    }

    function clearAll() {
        notifModel.clear()
    }
}
