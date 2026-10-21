pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import Caelestia.Config
import qs.components
import qs.services
import qs.utils

Item {
    id: root

    implicitWidth: 850
    implicitHeight: 460

    // ---------- Data: reading ----------

    FileView {
        id: todoFile

        path: `${Paths.home}/Sync/todo.md`
        blockLoading: true
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var tasks: parseTodo(todoFile.text())
    readonly property var openTasks: tasks.filter(t => !t.done)
    readonly property var doneTasks: tasks.filter(t => t.done)
    readonly property real progress: tasks.length > 0 ? doneTasks.length / tasks.length : 0

    property bool showDone: true

    // ---------- Selection ----------

    property int selectedIndex: -1
    readonly property var selectedTask: selectedIndex >= 0 && selectedIndex < tasks.length ? tasks[selectedIndex] : null

    property int noteOwner: -1
    property bool loadingNote: false

    function loadNote() {
        const task = validTask(selectedIndex) ? tasks[selectedIndex] : null;
        loadingNote = true;
        noteOwner = selectedIndex;
        noteEdit.text = task ? task.note : "";
        loadingNote = false;
    }

    function flushNote() {
        if (noteTimer.running) {
            noteTimer.stop();
            setNote(noteOwner, noteEdit.text);
        }
    }

    onSelectedIndexChanged: {
        flushNote();
        noteEdit.focus = false;
        loadNote();
    }

    onTasksChanged: {
        if (selectedIndex >= tasks.length)
            selectedIndex = -1;
        else if (!noteEdit.activeFocus)
            loadNote();
    }

    function parseTodo(text) {
        const result = [];
        let current = null;

        for (const line of text.split("\n")) {
            const task = line.match(/^- \[( |x|X)\] (.*)$/);
            if (task) {
                current = { index: result.length, done: task[1] !== " ", text: task[2], steps: [], note: "" };
                result.push(current);
                continue;
            }

            if (!current)
                continue;

            const step = line.match(/^\s+- \[( |x|X)\] (.*)$/);
            if (step) {
                current.steps.push({ done: step[1] !== " ", text: step[2] });
                continue;
            }

            const note = line.match(/^\s+> ?(.*)$/);
            if (note)
                current.note += (current.note ? "\n" : "") + note[1];
        }

        return result;
    }

    // ---------- Data: writing ----------

    function serialize(list) {
        const lines = [];
        for (const t of list) {
            lines.push(`- [${t.done ? "x" : " "}] ${t.text}`);
            for (const s of t.steps)
                lines.push(`    - [${s.done ? "x" : " "}] ${s.text}`);
            if (t.note)
                for (const n of t.note.split("\n"))
                    lines.push(`    > ${n}`);
        }
        return lines.join("\n") + "\n";
    }

    function copyTasks() {
        return JSON.parse(JSON.stringify(tasks));
    }

    function save(list) {
        todoFile.setText(serialize(list));
    }

    function validTask(i) {
        return i >= 0 && i < tasks.length;
    }

    function toggleTask(i) {
        if (!validTask(i))
            return;
        const list = copyTasks();
        list[i].done = !list[i].done;
        save(list);
    }

    function deleteTask(i) {
        if (!validTask(i))
            return;
        if (i === selectedIndex) {
            noteTimer.stop();
            selectedIndex = -1;
        } else if (i < selectedIndex) {
            flushNote();
            selectedIndex -= 1;
        }
        const list = copyTasks();
        list.splice(i, 1);
        save(list);
    }

    function addTask(text) {
        const list = copyTasks();
        list.push({ done: false, text: text, steps: [], note: "" });
        save(list);
    }

    function toggleStep(ti, si) {
        if (!validTask(ti))
            return;
        const list = copyTasks();
        list[ti].steps[si].done = !list[ti].steps[si].done;
        save(list);
    }

    function deleteStep(ti, si) {
        if (!validTask(ti))
            return;
        const list = copyTasks();
        list[ti].steps.splice(si, 1);
        save(list);
    }

    function addStep(ti, text) {
        if (!validTask(ti))
            return;
        const list = copyTasks();
        list[ti].steps.push({ done: false, text: text });
        save(list);
    }

    function setNote(ti, note) {
        if (!validTask(ti))
            return;
        const list = copyTasks();
        list[ti].note = note.replace(/\s+$/, "");
        save(list);
    }

    Timer {
        id: noteTimer

        interval: 800
        onTriggered: root.setNote(root.noteOwner, noteEdit.text)
    }

    // ---------- Left card: task list ----------

    StyledRect {
        id: listCard

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: sideCard.left
        anchors.rightMargin: Tokens.padding.large

        radius: Tokens.rounding.largeIncreased
        color: Colours.tPalette.m3surfaceContainer

        StyledText {
            id: header

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Tokens.padding.extraLarge
            text: "To-do"
            color: Colours.palette.m3primary
            font.pointSize: 20
        }

        StyledText {
            anchors.right: parent.right
            anchors.baseline: header.baseline
            anchors.rightMargin: Tokens.padding.extraLarge
            text: `${root.openTasks.length} left`
            color: Colours.palette.m3onSurfaceVariant
        }

        Flickable {
            anchors.top: header.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: addRow.top
            anchors.margins: Tokens.padding.large
            contentHeight: list.implicitHeight
            clip: true

            Column {
                id: list

                width: parent.width
                spacing: Tokens.spacing.small

                Repeater {
                    model: root.openTasks

                    delegate: TaskRow {
                        selected: modelData.index === root.selectedIndex
                        onToggled: root.toggleTask(modelData.index)
                        onDeleteRequested: root.deleteTask(modelData.index)
                        onOpened: root.selectedIndex = root.selectedIndex === modelData.index ? -1 : modelData.index
                    }
                }

                Item {
                    width: parent.width
                    height: completedLabel.implicitHeight + Tokens.padding.large * 2

                    Row {
                        id: completedLabel

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Tokens.spacing.small

                        MaterialIcon {
                            text: "chevron_right"
                            color: Colours.palette.m3onSurfaceVariant
                            rotation: root.showDone ? 90 : 0

                            Behavior on rotation {
                                Anim {}
                            }
                        }

                        StyledText {
                            text: `Completed (${root.doneTasks.length})`
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showDone = !root.showDone
                    }
                }

                Repeater {
                    model: root.showDone ? root.doneTasks : []

                    delegate: TaskRow {
                        selected: modelData.index === root.selectedIndex
                        onToggled: root.toggleTask(modelData.index)
                        onDeleteRequested: root.deleteTask(modelData.index)
                        onOpened: root.selectedIndex = root.selectedIndex === modelData.index ? -1 : modelData.index
                    }
                }
            }
        }

        StyledRect {
            id: addRow

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.large
            implicitHeight: addIcon.implicitHeight + Tokens.padding.large * 2

            radius: Tokens.rounding.large
            color: Colours.palette.m3surfaceContainerHighest

            MaterialIcon {
                id: addIcon

                anchors.left: parent.left
                anchors.leftMargin: Tokens.padding.large
                anchors.verticalCenter: parent.verticalCenter
                text: "add"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                id: addPlaceholder

                anchors.left: addIcon.right
                anchors.leftMargin: Tokens.padding.medium
                anchors.verticalCenter: parent.verticalCenter
                text: "Add a task"
                color: Colours.palette.m3onSurfaceVariant
                visible: addInput.text === ""
            }

            TextInput {
                id: addInput

                anchors.left: addPlaceholder.left
                anchors.right: parent.right
                anchors.rightMargin: Tokens.padding.large
                anchors.verticalCenter: parent.verticalCenter
                font: addPlaceholder.font
                color: Colours.palette.m3onSurface
                clip: true

                onAccepted: {
                    const value = text.trim();
                    if (value !== "")
                        root.addTask(value);
                    text = "";
                }
            }
        }
    }

    component TaskRow: StyledRect {
        id: row

        required property var modelData
        property bool selected: false

        signal toggled
        signal deleteRequested
        signal opened

        readonly property color baseColour: Qt.lighter(Colours.palette.m3surfaceContainerHighest, 2.5)

        width: parent ? parent.width : 0
        implicitHeight: Math.max(textColumn.implicitHeight, checkIcon.implicitHeight) + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: {
            if (selected)
                return Colours.palette.m3secondaryContainer;
            if (modelData.done)
                return hover.hovered ? Qt.alpha(baseColour, 0.4) : "transparent";
            return hover.hovered ? Qt.lighter(baseColour, 1.12) : baseColour;
        }

        Behavior on color {
            CAnim {}
        }

        HoverHandler {
            id: hover
        }

        // Whole-row click area (declared first, so the icons above it get their own clicks)
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.opened()
        }

        MaterialIcon {
            id: checkIcon

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.large
            anchors.verticalCenter: parent.verticalCenter
            text: row.modelData.done ? "check_circle" : "radio_button_unchecked"
            fill: row.modelData.done ? 1 : 0
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.large

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Tokens.padding.large
                cursorShape: Qt.PointingHandCursor
                onClicked: row.toggled()
            }
        }

        Column {
            id: textColumn

            anchors.left: checkIcon.right
            anchors.leftMargin: Tokens.padding.medium
            anchors.right: deleteIcon.left
            anchors.rightMargin: Tokens.padding.medium
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: row.modelData.text
                color: row.modelData.done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
                font.strikeout: row.modelData.done
                elide: Text.ElideRight
            }

            StyledText {
                visible: !row.modelData.done && (row.modelData.steps.length > 0 || row.modelData.note !== "")
                text: {
                    const parts = [];
                    if (row.modelData.steps.length > 0)
                        parts.push(`${row.modelData.steps.filter(s => s.done).length} of ${row.modelData.steps.length} steps`);
                    if (row.modelData.note !== "")
                        parts.push("note");
                    return parts.join("  ·  ");
                }
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: 9
            }
        }

        MaterialIcon {
            id: deleteIcon

            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.large
            anchors.verticalCenter: parent.verticalCenter
            text: "delete"
            color: Colours.palette.m3onSurfaceVariant
            opacity: hover.hovered ? 1 : 0

            Behavior on opacity {
                Anim {}
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Tokens.padding.large
                enabled: hover.hovered
                cursorShape: Qt.PointingHandCursor
                onClicked: row.deleteRequested()
            }
        }
    }

    component StepRow: Item {
        id: step

        required property var modelData
        required property int index

        signal toggled
        signal deleteRequested

        width: parent ? parent.width : 0
        implicitHeight: Math.max(stepText.implicitHeight, stepIcon.implicitHeight) + Tokens.padding.small * 2

        HoverHandler {
            id: stepHover
        }

        MaterialIcon {
            id: stepIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: step.modelData.done ? "check_circle" : "radio_button_unchecked"
            fill: step.modelData.done ? 1 : 0
            color: Colours.palette.m3primary
            fontStyle: Tokens.font.icon.medium

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Tokens.padding.small
                cursorShape: Qt.PointingHandCursor
                onClicked: step.toggled()
            }
        }

        StyledText {
            id: stepText

            anchors.left: stepIcon.right
            anchors.leftMargin: Tokens.padding.medium
            anchors.right: stepDelete.left
            anchors.rightMargin: Tokens.padding.small
            anchors.verticalCenter: parent.verticalCenter
            text: step.modelData.text
            wrapMode: Text.Wrap
            color: step.modelData.done ? Colours.palette.m3onSurfaceVariant : Colours.palette.m3onSurface
            font.strikeout: step.modelData.done
        }

        MaterialIcon {
            id: stepDelete

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "close"
            color: Colours.palette.m3onSurfaceVariant
            opacity: stepHover.hovered ? 1 : 0

            Behavior on opacity {
                Anim {}
            }

            MouseArea {
                anchors.fill: parent
                anchors.margins: -Tokens.padding.small
                enabled: stepHover.hovered
                cursorShape: Qt.PointingHandCursor
                onClicked: step.deleteRequested()
            }
        }
    }

    // ---------- Right card: progress OR task details ----------

    StyledRect {
        id: sideCard

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 340

        radius: Tokens.rounding.largeIncreased
        color: Colours.tPalette.m3surfaceContainer

        // ----- Progress view (nothing selected) -----

        Item {
            id: progressView

            anchors.fill: parent
            visible: root.selectedTask === null

            Column {
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: Tokens.padding.extraLarge
                spacing: Tokens.spacing.small

                Item {
                    width: 170
                    height: 170

                    Canvas {
                        id: ring

                        anchors.fill: parent

                        property real progress: root.progress
                        property color trackColour: Colours.palette.m3surfaceContainerHighest
                        property color fillColour: Colours.palette.m3primary

                        onProgressChanged: requestPaint()
                        onTrackColourChanged: requestPaint()
                        onFillColourChanged: requestPaint()

                        onPaint: {
                            const ctx = getContext("2d");
                            const r = width / 2 - 12;
                            ctx.reset();
                            ctx.lineWidth = 12;
                            ctx.lineCap = "round";

                            ctx.strokeStyle = trackColour;
                            ctx.beginPath();
                            ctx.arc(width / 2, height / 2, r, 0, Math.PI * 2);
                            ctx.stroke();

                            if (progress > 0) {
                                ctx.strokeStyle = fillColour;
                                ctx.beginPath();
                                ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * progress);
                                ctx.stroke();
                            }
                        }
                    }

                    Column {
                        anchors.centerIn: parent

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: `${root.doneTasks.length}/${root.tasks.length}`
                            color: Colours.palette.m3primary
                            font.pointSize: 22
                        }

                        StyledText {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "done"
                            color: Colours.palette.m3onSurfaceVariant
                        }
                    }
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.openTasks.length === 0 ? "All done. Nice work!" : `${root.openTasks.length} to go`
                }

                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Click a task for steps and notes"
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: 9
                }
            }

            StyledText {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: Tokens.padding.large
                text: "Synced · ~/Sync/todo.md"
                color: Colours.palette.m3onSurfaceVariant
                font.pointSize: 9
            }
        }

        // ----- Detail view (a task is selected) -----

        Item {
            id: detailView

            anchors.fill: parent
            anchors.margins: Tokens.padding.large
            visible: root.selectedTask !== null

            StyledRect {
                id: closeButton

                anchors.top: parent.top
                anchors.right: parent.right
                implicitWidth: closeIcon.implicitWidth + Tokens.padding.small * 2
                implicitHeight: closeIcon.implicitHeight + Tokens.padding.small * 2
                radius: Tokens.rounding.full
                color: Colours.palette.m3surfaceContainerHighest

                MaterialIcon {
                    id: closeIcon

                    anchors.centerIn: parent
                    text: "close"
                    color: Colours.palette.m3onSurfaceVariant
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectedIndex = -1
                }
            }

            StyledRect {
                id: titleRow

                anchors.top: closeButton.bottom
                anchors.topMargin: Tokens.padding.small
                anchors.left: parent.left
                anchors.right: parent.right
                implicitHeight: Math.max(titleText.implicitHeight, titleIcon.implicitHeight) + Tokens.padding.large * 2
                radius: Tokens.rounding.large
                color: Colours.palette.m3surfaceContainerHighest

                MaterialIcon {
                    id: titleIcon

                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.padding.large
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedTask?.done ? "check_circle" : "radio_button_unchecked"
                    fill: root.selectedTask?.done ? 1 : 0
                    color: Colours.palette.m3primary
                    fontStyle: Tokens.font.icon.large

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -Tokens.padding.small
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleTask(root.selectedIndex)
                    }
                }

                StyledText {
                    id: titleText

                    anchors.left: titleIcon.right
                    anchors.leftMargin: Tokens.padding.medium
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.padding.large
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selectedTask?.text ?? ""
                    wrapMode: Text.Wrap
                    font.pointSize: 13
                    font.strikeout: root.selectedTask?.done ?? false
                }
            }

            Flickable {
                anchors.top: titleRow.bottom
                anchors.topMargin: Tokens.padding.large
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                contentHeight: detailColumn.implicitHeight
                clip: true

                Column {
                    id: detailColumn

                    width: parent.width
                    spacing: Tokens.spacing.small

                    StyledText {
                        text: "Steps"
                        color: Colours.palette.m3primary
                    }

                    Repeater {
                        model: root.selectedTask ? root.selectedTask.steps : []

                        delegate: StepRow {
                            onToggled: root.toggleStep(root.selectedIndex, index)
                            onDeleteRequested: root.deleteStep(root.selectedIndex, index)
                        }
                    }

                    Item {
                        width: parent.width
                        implicitHeight: stepAddIcon.implicitHeight + Tokens.padding.small * 2

                        MaterialIcon {
                            id: stepAddIcon

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: "add"
                            color: Colours.palette.m3primary
                            fontStyle: Tokens.font.icon.medium
                        }

                        StyledText {
                            id: stepPlaceholder

                            anchors.left: stepAddIcon.right
                            anchors.leftMargin: Tokens.padding.medium
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Add a step"
                            color: Colours.palette.m3onSurfaceVariant
                            visible: stepInput.text === ""
                        }

                        TextInput {
                            id: stepInput

                            anchors.left: stepPlaceholder.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            font: stepPlaceholder.font
                            color: Colours.palette.m3onSurface
                            clip: true

                            onAccepted: {
                                const value = text.trim();
                                if (value !== "")
                                    root.addStep(root.selectedIndex, value);
                                text = "";
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: Tokens.padding.large
                    }

                    StyledText {
                        text: "Note"
                        color: Colours.palette.m3primary
                    }

                    StyledRect {
                        width: parent.width
                        implicitHeight: Math.max(noteEdit.implicitHeight, 100) + Tokens.padding.large * 2
                        radius: Tokens.rounding.large
                        color: Colours.palette.m3surfaceContainerHighest

                        StyledText {
                            id: notePlaceholder

                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.margins: Tokens.padding.large
                            text: "Add a note"
                            color: Colours.palette.m3onSurfaceVariant
                            visible: noteEdit.text === "" && !noteEdit.activeFocus
                        }

                        TextEdit {
                            id: noteEdit

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: Tokens.padding.large
                            font: notePlaceholder.font
                            color: Colours.palette.m3onSurface
                            wrapMode: TextEdit.Wrap
                            selectByMouse: true

                            onTextChanged: {
                                if (!root.loadingNote && activeFocus)
                                    noteTimer.restart();
                            }

                            onActiveFocusChanged: {
                                if (!activeFocus)
                                    root.flushNote();
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            z: -1
                            cursorShape: Qt.IBeamCursor
                            onClicked: noteEdit.forceActiveFocus()
                        }
                    }
                }
            }
        }
    }
}