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
    implicitHeight: 450

    // ---------- Data: reading ----------

    FileView {
        id: todoFile

        path: `${Paths.home}/Sync/todo.md`
        watchChanges: true
        onFileChanged: reload()
    }

    readonly property var tasks: parseTodo(todoFile.text())
    readonly property var openTasks: tasks.filter(t => !t.done)
    readonly property var doneTasks: tasks.filter(t => t.done)
    readonly property real progress: tasks.length > 0 ? doneTasks.length / tasks.length : 0

    property bool showDone: true

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

    function toggleTask(i) {
        const list = copyTasks();
        list[i].done = !list[i].done;
        save(list);
    }

    function deleteTask(i) {
        const list = copyTasks();
        list.splice(i, 1);
        save(list);
    }

    function addTask(text) {
        const list = copyTasks();
        list.push({ done: false, text: text, steps: [], note: "" });
        save(list);
    }

    // ---------- Left card: task list ----------

    StyledRect {
        id: listCard

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: progressCard.left
        anchors.rightMargin: Tokens.padding.large

        radius: Tokens.rounding.largeIncreased
        color: Colours.palette.m3surfaceContainer

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
                        onToggled: root.toggleTask(modelData.index)
                        onDeleteRequested: root.deleteTask(modelData.index)
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
                        onToggled: root.toggleTask(modelData.index)
                        onDeleteRequested: root.deleteTask(modelData.index)
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

        signal toggled
        signal deleteRequested

        width: parent ? parent.width : 0
        implicitHeight: Math.max(textColumn.implicitHeight, checkIcon.implicitHeight) + Tokens.padding.large * 2
        radius: Tokens.rounding.large
        color: modelData.done ? "transparent" : Colours.palette.m3surfaceContainerHighest

        HoverHandler {
            id: hover
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
                anchors.margins: -Tokens.padding.small
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
                anchors.margins: -Tokens.padding.small
                enabled: hover.hovered
                cursorShape: Qt.PointingHandCursor
                onClicked: row.deleteRequested()
            }
        }
    }

    // ---------- Right card: progress ----------

    StyledRect {
        id: progressCard

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 280

        radius: Tokens.rounding.largeIncreased
        color: Colours.palette.m3surfaceContainer

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
}