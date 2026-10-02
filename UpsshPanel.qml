import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.Ui as Ui

// upSSH — an icon in the bar and a panel to connect to, add and edit
// servers. All management happens here; a terminal is only opened for the
// SSH session itself.
//
// Data lives in ~/.config/upssh/servers.json and passwords in the GPG
// vault next to it; the panel never touches them directly — it always talks
// to the `upssh` command, which is the only thing that knows how to encrypt
// and which keeps the Omarchy menu in sync.
Panel {
  id: root
  moduleName: "io.github.wegnix.upssh"
  ipcTarget: "io.github.wegnix.upssh"
  manageIpc: true

  // The base Panel is an Item with no size of its own: without this the bar
  // button ends up 0px wide and the widget does not show.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ------------------------------------------------------------------- state
  property var servers: []
  property string filterText: ""
  property string view: "list" // "list" | "form"
  property string status: ""
  property bool statusIsError: false
  property string armedDelete: ""
  property int cursorIndex: 0
  property bool cursorActive: false
  property bool busy: false

  // form fields
  property string fId: ""
  property string fName: ""
  property string fGroup: ""
  property string fNewGroup: ""
  property string fHost: ""
  property string fPort: "22"
  property string fUser: "root"
  property string fAuth: "key"
  property string fIdentity: ""
  property string fOptions: ""
  property string fPassword: ""

  // export / import
  property bool exportWithSecrets: false
  property string exportPass: ""
  property string exportPath: ""
  property string importFile: ""
  property string importPass: ""
  property var importConflicts: []
  property string importPolicy: "manter"

  // The file dialog steals focus and the panel closes; this flags the trip
  // to the dialog so it can be reopened without wiping what was filled in.
  property bool dialogPending: false

  // The export path came from the dialog, which already asked before
  // overwriting a file; when typed by hand, the command refuses to overwrite.
  property bool exportPathConfirmed: false

  // Nothing is run until we know which `upssh` to use (the plugin's or the
  // PATH one); before that a foreign `upssh` on the PATH could be called.
  property bool probed: false
  property bool reloadPending: false

  // zenity is optional; without it the "Browse…" buttons do not even show (a
  // Process that fails to start never emits exited and would leave the panel stuck).
  property bool hasZenity: false


  // ---------------------------------------------------------- translations
  // The language comes from `upssh lang`, so the panel and the command line
  // always speak the same one.
  property string lang: "pt"

  // Installing with `omarchy plugin add` puts the command inside the plugin
  // folder, off the PATH; install.sh puts it in ~/.local/bin. This path
  // covers both, always preferring the one shipped with the plugin.
  readonly property string pluginDir: {
    var d = String(Qt.resolvedUrl("."))
    return decodeURIComponent(d.indexOf("file://") === 0 ? d.substring(7) : d)
  }
  readonly property string cmd: bundled ? pluginDir + "bin/upssh" : "upssh"
  property bool bundled: false
  readonly property var tr: lang === "en" ? enStrings : ptStrings

  readonly property var ptStrings: ({
    title: "upSSH",
    newServer: "Novo servidor",
    editServer: "Editar servidor",
    exportTitle: "Exportar servidores",
    importTitle: "Importar servidores",
    formHint: "Os campos vazios ficam com o valor por omissão",
    metaEncrypted: "Ficheiro .gpg cifrado com AES-256",
    metaPlain: "JSON legível, sem senhas",
    pickAFile: "Escolhe um ficheiro",
    servers: " servidores · ",
    groups: " grupos",
    visible: " visíveis",
    addTip: "Cadastrar servidor (n)",
    backTip: "Voltar (Esc)",
    filterPh: "Filtrar por nome, grupo, host ou login…",
    emptyFirst: "Ainda não há servidores. Carrega em + para cadastrar o primeiro.",
    emptyFilter: "Nada corresponde ao filtro.",
    lName: "Nome de identificação",
    phName: "Ex.: Docker 01",
    lGroup: "Grupo",
    newGroupOpt: "+ Novo grupo…",
    lNewGroup: "Nome do novo grupo",
    phNewGroup: "Ex.: Clientes",
    lHost: "Host (IP ou DNS)",
    phHost: "10.0.0.1 ou servidor.exemplo.com",
    lPort: "Porta",
    lUser: "Login / Utilizador",
    lAuth: "Autenticação",
    authKey: "Chave SSH / agente",
    authPass: "Senha (guardada cifrada)",
    lIdentity: "Ficheiro de chave privada (opcional)",
    phIdentity: "~/.ssh/id_ed25519 — vazio usa as chaves do agente",
    lPass: "Senha",
    lPassKeep: "Senha (vazio mantém a actual)",
    phPass: "Guardada no cofre GPG",
    lOptions: "Opções extra do ssh (opcional)",
    save: "Guardar",
    saving: "A guardar…",
    cancel: "Cancelar",
    inclSecrets: "Incluir as senhas guardadas",
    inclSecretsDesc: "O ficheiro passa a ser um .gpg cifrado com AES-256 e uma senha só dele — separada da senha mestra do cofre.",
    lExportPass: "Senha do ficheiro exportado",
    phExportPass: "Vais precisar dela para importar noutra máquina",
    lSaveTo: "Guardar em",
    phSaveTo: "/caminho/para/o/ficheiro",
    browseSave: "Escolher pasta e nome…",
    doExport: "Exportar",
    exporting: "A exportar…",
    lImportFile: "Ficheiro a importar",
    phImportFile: "/caminho/para/upssh-….json",
    lFilePass: "Senha do ficheiro",
    phFilePass: "A que definiste ao exportar",
    alreadyHere: "Já existem aqui: ",
    lPolicy: "Quando o servidor já existe",
    pKeep: "Manter o que já tenho",
    pReplace: "Substituir pelo importado",
    pCopy: "Importar como cópia",
    doImport: "Importar",
    importing: "A importar…",
    pickImportTitle: "upSSH — importar servidores",
    pickExportTitle: "upSSH — guardar exportação",
    filterExports: "Exportações do upSSH",
    filterAll: "Todos os ficheiros",
    browse: "Procurar…",
    syncTip: "Sincronizar o menu do Omarchy",
    masterTip: "Alterar a senha mestra do cofre",
    langTip: "Português / English",
    editTip: "Editar (e)",
    removeTip: "Remover (x)",
    confirmAgain: "Carrega outra vez para confirmar",
    armRemove: "Carrega outra vez para remover ",
    barTip: "upSSH — ",
    barTipServers: " servidores",
    needName: "Dá um nome ao servidor.",
    needHost: "Falta o host.",
    needUser: "Falta o utilizador.",
    needGroup: "Escolhe ou cria um grupo.",
    badPort: "Porta inválida: ",
    saved: "Guardado.",
    savedVault: "Guardado, senha no cofre.",
    saveFail: "Não foi possível guardar.",
    savePassFail: "Servidor guardado, mas a senha não entrou no cofre.",
    removing: "A remover…",
    removed: "Removido.",
    removeFail: "Não foi possível remover.",
    syncing: "A sincronizar o menu…",
    synced: "Menu do Omarchy sincronizado.",
    syncFail: "Falha ao sincronizar.",
    readFail: "Não consegui ler servers.json.",
    needDest: "Indica onde guardar o ficheiro.",
    needFilePass: "Define a senha que vai cifrar o ficheiro.",
    exportedTo: "Exportado para ",
    exportFail: "A exportação falhou.",
    importFail: "A importação falhou.",
    destIs: "Destino: ",
    destUnchanged: "Destino não alterado.",
    choosingFile: "A escolher o ficheiro…",
    choosingDest: "A escolher o destino…",
    noFileChosen: "Nenhum ficheiro escolhido — podes escrever o caminho."
  })

  readonly property var enStrings: ({
    title: "upSSH",
    newServer: "New server",
    editServer: "Edit server",
    exportTitle: "Export servers",
    importTitle: "Import servers",
    formHint: "Empty fields fall back to the default",
    metaEncrypted: "AES-256 encrypted .gpg file",
    metaPlain: "Readable JSON, no passwords",
    pickAFile: "Pick a file",
    servers: " servers · ",
    groups: " groups",
    visible: " shown",
    addTip: "Add server (n)",
    backTip: "Back (Esc)",
    filterPh: "Filter by name, group, host or login…",
    emptyFirst: "No servers yet. Hit + to register the first one.",
    emptyFilter: "Nothing matches the filter.",
    lName: "Display name",
    phName: "e.g. Docker 01",
    lGroup: "Group",
    newGroupOpt: "+ New group…",
    lNewGroup: "New group name",
    phNewGroup: "e.g. Customers",
    lHost: "Host (IP or DNS)",
    phHost: "10.0.0.1 or server.example.com",
    lPort: "Port",
    lUser: "Login / user",
    lAuth: "Authentication",
    authKey: "SSH key / agent",
    authPass: "Password (stored encrypted)",
    lIdentity: "Private key file (optional)",
    phIdentity: "~/.ssh/id_ed25519 — empty uses the agent keys",
    lPass: "Password",
    lPassKeep: "Password (empty keeps the current one)",
    phPass: "Stored in the GPG vault",
    lOptions: "Extra ssh options (optional)",
    save: "Save",
    saving: "Saving…",
    cancel: "Cancel",
    inclSecrets: "Include the stored passwords",
    inclSecretsDesc: "The file becomes an AES-256 encrypted .gpg with a password of its own — separate from the vault master password.",
    lExportPass: "Password for the exported file",
    phExportPass: "You will need it to import on another machine",
    lSaveTo: "Save to",
    phSaveTo: "/path/to/the/file",
    browseSave: "Choose folder and name…",
    doExport: "Export",
    exporting: "Exporting…",
    lImportFile: "File to import",
    phImportFile: "/path/to/upssh-….json",
    lFilePass: "File password",
    phFilePass: "The one you set when exporting",
    alreadyHere: "Already here: ",
    lPolicy: "When the server already exists",
    pKeep: "Keep what I have",
    pReplace: "Replace with the imported one",
    pCopy: "Import as a copy",
    doImport: "Import",
    importing: "Importing…",
    pickImportTitle: "upSSH — import servers",
    pickExportTitle: "upSSH — save export",
    filterExports: "upSSH exports",
    filterAll: "All files",
    browse: "Browse…",
    syncTip: "Sync the Omarchy menu",
    masterTip: "Change the vault master password",
    langTip: "English / Português",
    editTip: "Edit (e)",
    removeTip: "Remove (x)",
    confirmAgain: "Press again to confirm",
    armRemove: "Press again to remove ",
    barTip: "upSSH — ",
    barTipServers: " servers",
    needName: "Give the server a name.",
    needHost: "The host is missing.",
    needUser: "The user is missing.",
    needGroup: "Pick or create a group.",
    badPort: "Invalid port: ",
    saved: "Saved.",
    savedVault: "Saved, password in the vault.",
    saveFail: "Could not save.",
    savePassFail: "Server saved, but the password did not reach the vault.",
    removing: "Removing…",
    removed: "Removed.",
    removeFail: "Could not remove.",
    syncing: "Syncing the menu…",
    synced: "Omarchy menu synced.",
    syncFail: "Sync failed.",
    readFail: "Could not read servers.json.",
    needDest: "Say where to save the file.",
    needFilePass: "Set the password that will encrypt the file.",
    exportedTo: "Exported to ",
    exportFail: "The export failed.",
    importFail: "The import failed.",
    destIs: "Target: ",
    destUnchanged: "Target unchanged.",
    choosingFile: "Choosing the file…",
    choosingDest: "Choosing the target…",
    noFileChosen: "No file chosen — you can type the path instead."
  })

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color accent: Color.accent
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property bool vertical: bar ? bar.vertical : false

  readonly property string newGroupSentinel: "\u0000new"

  readonly property var groupNames: {
    var seen = {}
    var out = []
    for (var i = 0; i < servers.length; i++) {
      var g = String(servers[i].group || "")
      if (g === "" || seen[g]) continue
      seen[g] = true
      out.push(g)
    }
    out.sort()
    return out
  }

  // A row matches if the text appears in the name, group, host or login,
  // so "docker", "upnet" and "10.0.8" all lead to the same place.
  function matches(s) {
    var q = filterText.trim().toLowerCase()
    if (q === "") return true
    var hay = [s.name, s.group, s.host, s.user, String(s.port)].join(" ").toLowerCase()
    var parts = q.split(/\s+/)
    for (var i = 0; i < parts.length; i++)
      if (hay.indexOf(parts[i]) === -1) return false
    return true
  }

  readonly property var sections: {
    var out = []
    for (var g = 0; g < groupNames.length; g++) {
      var rows = []
      for (var i = 0; i < servers.length; i++) {
        var s = servers[i]
        if (String(s.group || "") !== groupNames[g]) continue
        if (!matches(s)) continue
        rows.push(s)
      }
      if (rows.length > 0) out.push({ group: groupNames[g], rows: rows })
    }
    return out
  }

  readonly property var flatRows: {
    var out = []
    for (var i = 0; i < sections.length; i++)
      for (var j = 0; j < sections[i].rows.length; j++)
        out.push(sections[i].rows[j])
    return out
  }

  readonly property var currentRow: flatRows.length === 0
    ? null
    : flatRows[Math.max(0, Math.min(cursorIndex, flatRows.length - 1))]

  function rowOffset(sectionIndex) {
    var n = 0
    for (var i = 0; i < sectionIndex; i++) n += sections[i].rows.length
    return n
  }

  // ----------------------------------------------------------------- actions
  function setStatus(text, isError) {
    root.status = String(text || "")
    root.statusIsError = !!isError
  }

  // A request that arrives while a read is in progress is flagged and runs
  // afterwards, so the list never keeps the state from before saving.
  function refresh() {
    if (!probed) return
    if (loadProc.running) { reloadPending = true; return }
    loadProc.running = true
  }

  function moveCursor(delta) {
    if (flatRows.length === 0) return
    cursorActive = true
    cursorIndex = Math.max(0, Math.min(flatRows.length - 1, cursorIndex + delta))
    armedDelete = ""
  }

  function setCursor(index) {
    cursorActive = true
    cursorIndex = index
  }

  function connectRow(row) {
    if (!row || !bar) return
    // The injected `bar` exposes run() but not shellQuote() — that lives in
    // qs.Commons.Util, and calling it on the wrong object aborted the whole binding.
    bar.run("omarchy-launch-tui --app-id=org.upssh " + Util.shellQuote(root.cmd) + " connect " + Util.shellQuote(String(row.id)))
    root.close()
  }

  // While a command runs, the screen does not change: its result applies
  // to the form that launched it, never to another one opened meanwhile.
  function openForm(row) {
    if (busy) return
    armedDelete = ""
    setStatus("", false)
    if (row) {
      fId = String(row.id)
      fName = String(row.name || "")
      fGroup = String(row.group || "")
      fHost = String(row.host || "")
      fPort = String(row.port || 22)
      fUser = String(row.user || "")
      fAuth = String(row.auth || "key")
      fIdentity = String(row.identity || "")
      fOptions = String(row.options || "")
    } else {
      fId = ""
      fName = ""
      fGroup = groupNames.length > 0 ? groupNames[0] : newGroupSentinel
      fHost = ""
      fPort = "22"
      fUser = "root"
      fAuth = "key"
      fIdentity = ""
      fOptions = ""
    }
    fNewGroup = ""
    fPassword = ""
    view = "form"
  }

  // keepStatus: closing after saving keeps the success message.
  function closeForm(keepStatus) {
    if (busy) return
    view = "list"
    fPassword = ""
    exportPass = ""
    importPass = ""
    if (!keepStatus) setStatus("", false)
  }

  function effectiveGroup() {
    return fGroup === newGroupSentinel ? fNewGroup.trim() : fGroup
  }

  function saveForm() {
    if (busy) return
    if (fName.trim() === "") { setStatus(root.tr.needName, true); return }
    if (fHost.trim() === "") { setStatus(root.tr.needHost, true); return }
    if (fUser.trim() === "") { setStatus(root.tr.needUser, true); return }
    if (effectiveGroup() === "") { setStatus(root.tr.needGroup, true); return }
    var port = fPort.trim() === "" ? "22" : fPort.trim()
    if (!/^\d+$/.test(port)) { setStatus(root.tr.badPort + port, true); return }

    root.busy = true
    setStatus(root.tr.saving, false)
    saveProc.pendingPassword = fAuth === "password" ? fPassword : ""
    saveProc.collected = ""
    saveProc.command = [root.cmd, "save",
      "--id", fId,
      "--name", fName.trim(),
      "--group", effectiveGroup(),
      "--host", fHost.trim(),
      "--port", port,
      "--user", fUser.trim(),
      "--auth", fAuth,
      "--identity", fAuth === "key" ? fIdentity.trim() : "",
      "--options", fOptions.trim()]
    saveProc.running = true
  }

  function requestDelete(row) {
    if (!row || busy) return
    if (armedDelete !== String(row.id)) {
      armedDelete = String(row.id)
      setStatus(root.tr.armRemove + row.name, true)
      armTimer.restart()
      return
    }
    armedDelete = ""
    armTimer.stop()
    root.busy = true
    setStatus(root.tr.removing, false)
    deleteProc.command = [root.cmd, "delete", String(row.id)]
    deleteProc.running = true
  }

  // Toggles pt/en and saves the choice, so the TUI and the menu follow it.
  function toggleLang() {
    if (busy || langSetProc.running) return
    var next = lang === "pt" ? "en" : "pt"
    langSetProc.command = [root.cmd, "lang", next]
    langSetProc.running = true
    lang = next
  }

  function changeMaster() {
    if (bar) bar.run(Util.shellQuote(root.cmd) + " master")
  }

  function defaultExportPath() {
    var stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-hhmmss")
    return Quickshell.env("HOME") + "/upssh-" + stamp + (exportWithSecrets ? ".gpg" : ".json")
  }

  function openExport() {
    if (busy) return
    exportWithSecrets = false
    exportPass = ""
    exportPath = defaultExportPath()
    exportPathConfirmed = false
    setStatus("", false)
    view = "export"
  }

  // The extension follows the format until the user picks a path of
  // their own — after that, what they typed wins.
  function retargetExport() {
    var want = exportWithSecrets ? ".gpg" : ".json"
    var other = exportWithSecrets ? ".json" : ".gpg"
    if (exportPath.endsWith(other)) {
      exportPath = exportPath.slice(0, -other.length) + want
      // A different name, which the dialog never confirmed.
      exportPathConfirmed = false
    }
  }

  function runExport() {
    if (busy) return
    if (exportWithSecrets && exportPass.trim() === "") {
      setStatus(root.tr.needFilePass, true)
      return
    }
    if (exportPath.trim() === "") {
      setStatus(root.tr.needDest, true)
      return
    }
    root.busy = true
    setStatus(root.tr.exporting, false)
    exportProc.collected = ""
    // The file password goes via stdin; the script reads it from there when
    // the request has no terminal, instead of opening a pinentry.
    exportProc.secret = exportWithSecrets ? exportPass : ""
    var cmd = [root.cmd, "export"]
    if (exportWithSecrets) cmd.push("--com-senhas", "--stdin-pass")
    // The dialog only confirmed this exact name; if the command has to
    // append the extension, it is a different file and must not be overwritten.
    if (exportPathConfirmed && /\.(json|gpg)$/.test(exportPath.trim())) cmd.push("--overwrite")
    cmd.push(exportPath.trim())
    exportProc.command = cmd
    exportProc.running = true
  }

  // zenity GTK dialog: Omarchy's picker relies on IPC with this very
  // process and does not respond when the shell is the one invoking it.
  function openImport() {
    if (busy) return
    importFile = ""
    importPass = ""
    importConflicts = []
    importPolicy = "manter"
    setStatus("", false)
    // Opens the screen only: the path is typed by hand and the file dialog
    // sits behind the "Browse…" button, for whoever wants it.
    view = "import"
  }

  function browseImport() {
    if (busy || !hasZenity) return
    setStatus(root.tr.choosingFile, false)
    dialogPending = true
    pickProc.collected = ""
    pickProc.running = true
  }

  function browseExport() {
    if (busy || !hasZenity) return
    setStatus(root.tr.choosingDest, false)
    dialogPending = true
    savePickProc.collected = ""
    savePickProc.command = ["zenity", "--file-selection", "--save",
                            "--confirm-overwrite",
                            "--title=" + root.tr.pickExportTitle,
                            "--filename=" + exportPath]
    savePickProc.running = true
  }

  // Shows the panel again after the dialog, with what was already there.
  function afterDialog() {
    // Order matters: open() fires onOpenedChanged immediately, and it is the flag,
    // still set, that stops that handler from clearing the form.
    if (!opened) open()
    dialogPending = false
  }

  // Shows which servers in the file already exist, by asking
  // `upssh import --dry-run` itself. A .gpg needs the password, so it is left
  // out (with --stdin-pass and stdin closed it never opens a pinentry).
  function checkConflicts() {
    importConflicts = []
    var file = importFile.trim()
    if (file === "" || file.endsWith(".gpg")) return
    if (conflictProc.running) { conflictTimer.restart(); return }
    conflictProc.collected = []
    conflictProc.command = [root.cmd, "import", file, "--dry-run", "--stdin-pass"]
    conflictProc.running = true
  }

  function runImport() {
    if (importFile === "" || busy) return
    root.busy = true
    setStatus(root.tr.importing, false)
    importProc.secret = importPass
    importProc.command = [root.cmd, "import", importFile,
                          "--conflito", importPolicy, "--stdin-pass"]
    importProc.running = true
  }

  function syncMenu() {
    if (busy) return
    root.busy = true
    setStatus(root.tr.syncing, false)
    syncProc.running = true
  }

  Timer {
    id: topTimer
    interval: 80
    repeat: false
    onTriggered: if (panelFlick) panelFlick.contentY = 0
  }

  Timer {
    id: armTimer
    interval: 3500
    onTriggered: { root.armedDelete = ""; root.setStatus("", false) }
  }

  // ---------------------------------------------------------------- processes
  // Read at startup and on every open: the language may have changed via the TUI.
  Component.onCompleted: probeProc.running = true

  // A single read at startup decides which of the two paths to use.
  Process {
    id: probeProc
    command: ["test", "-x", root.pluginDir + "bin/upssh"]
    onExited: function (code) {
      root.bundled = code === 0
      root.probed = true
      langProc.running = true
      zenityProbe.running = true
      root.refresh()
    }
  }

  Process {
    id: zenityProbe
    command: ["sh", "-c", "command -v zenity >/dev/null"]
    onExited: function (code) { root.hasZenity = code === 0 }
  }

  Process {
    id: langProc
    command: [root.cmd, "lang"]
    stdout: SplitParser {
      onRead: function (line) {
        var l = String(line).trim()
        if (l === "pt" || l === "en") root.lang = l
      }
    }
  }

  Process {
    id: langSetProc
    onExited: root.refresh()
  }

  // `upssh json` already caps the file at 1 MiB and filters out malformed
  // entries; it is checked again here because this is what feeds the list.
  readonly property int maxJson: 1048576

  function sanitizeServers(list) {
    var out = []
    if (!Array.isArray(list)) return out
    for (var i = 0; i < list.length && out.length < 5000; i++) {
      var s = list[i]
      if (!s || typeof s !== "object" || typeof s.id !== "string" || s.id === "") continue
      out.push({
        id: s.id,
        name: String(s.name || ""),
        group: String(s.group || ""),
        host: String(s.host || ""),
        port: String(s.port || 22),
        user: String(s.user || ""),
        auth: s.auth === "password" ? "password" : "key",
        identity: String(s.identity || ""),
        options: String(s.options || "")
      })
    }
    return out
  }

  Process {
    id: loadProc
    command: [root.cmd, "json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var raw = String(text || "")
        if (raw.length > root.maxJson) {
          root.servers = []
          root.setStatus(root.tr.readFail, true)
          return
        }
        try {
          var data = JSON.parse(raw === "" ? "{}" : raw)
          root.servers = root.sanitizeServers(data && data.servers)
        } catch (e) {
          root.servers = []
          root.setStatus(root.tr.readFail, true)
        }
      }
    }
    onExited: function (code) {
      // Corrupt or oversized file: `upssh json` refuses it, and that
      // must not show up as "no servers yet".
      if (code !== 0) {
        root.servers = []
        root.setStatus(root.tr.readFail, true)
      }
      if (root.reloadPending) {
        root.reloadPending = false
        loadProc.running = true
      }
    }
  }

  Process {
    id: saveProc
    property string pendingPassword: ""
    property string collected: ""
    stdout: SplitParser { onRead: function (line) { saveProc.collected += line } }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.setStatus(String(text).trim(), true)
    }
    onExited: function (code) {
      root.busy = false
      if (code !== 0) {
        if (root.status === "" || !root.statusIsError) root.setStatus(root.tr.saveFail, true)
        return
      }
      var id = saveProc.collected.trim()
      // From here on the server exists: if the password fails and the user
      // saves again, it is an edit of this id and not a duplicate.
      if (id !== "") root.fId = id
      if (saveProc.pendingPassword !== "" && id !== "") {
        // The password goes via stdin; never via argv, which is readable in `ps`.
        pwProc.secret = saveProc.pendingPassword
        saveProc.pendingPassword = ""
        pwProc.command = [root.cmd, "set-password", id]
        root.busy = true
        pwProc.running = true
        return
      }
      root.setStatus(root.tr.saved, false)
      root.closeForm(true)
      root.refresh()
    }
  }

  Process {
    id: pwProc
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.setStatus(String(text).trim(), true)
    }
    onExited: function (code) {
      root.busy = false
      if (code === 0) {
        root.setStatus(root.tr.savedVault, false)
        root.closeForm(true)
      } else if (!root.statusIsError) {
        root.setStatus(root.tr.savePassFail, true)
      }
      root.refresh()
    }
  }

  Process {
    id: deleteProc
    onExited: function (code) {
      root.busy = false
      root.setStatus(code === 0 ? root.tr.removed : root.tr.removeFail, code !== 0)
      root.refresh()
    }
  }

  Process {
    id: exportProc
    property string secret: ""
    property string collected: ""
    stdinEnabled: true
    // Always write a line, even an empty one: the script reads exactly one and,
    // without it, would wait forever with the panel blocked.
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
    stdout: SplitParser { onRead: function (line) { exportProc.collected = line } }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.setStatus(String(text).trim(), true)
    }
    onExited: function (code) {
      root.busy = false
      if (code === 0) {
        root.setStatus(root.tr.exportedTo + exportProc.collected.trim(), false)
        root.exportPass = ""
        root.view = "list"
      } else if (!root.statusIsError) {
        root.setStatus(root.tr.exportFail, true)
      }
    }
  }

  Process {
    id: savePickProc
    property string collected: ""
    stdout: SplitParser { onRead: function (line) { savePickProc.collected = line } }
    onExited: function (code) {
      var file = savePickProc.collected.trim()
      if (code === 0 && file !== "") {
        root.exportPath = file
        root.exportPathConfirmed = true
        root.setStatus(root.tr.destIs + file, false)
      } else {
        root.setStatus(root.tr.destUnchanged, false)
      }
      root.afterDialog()
    }
  }

  Process {
    id: pickProc
    property string collected: ""
    command: ["zenity", "--file-selection",
              "--title=" + root.tr.pickImportTitle,
              "--filename=" + Quickshell.env("HOME") + "/",
              "--file-filter=" + root.tr.filterExports + " | *.json *.gpg",
              "--file-filter=" + root.tr.filterAll + " | *"]
    stdout: SplitParser { onRead: function (line) { pickProc.collected = line } }
    onExited: function (code) {
      var file = pickProc.collected.trim()
      if (code !== 0 || file === "") {
        root.setStatus(root.tr.noFileChosen, false)
        root.afterDialog()
        return
      }
      root.importFile = file
      root.importPass = ""
      root.importPolicy = "manter"
      root.setStatus("", false)
      root.view = "import"
      root.checkConflicts()
      root.afterDialog()
    }
  }

  // A .gpg cannot be inspected without its password, so the conflict list
  // only appears for plaintext files; for encrypted ones the choice is
  // applied blind, as the user sets it.
  Process {
    id: conflictProc
    property var collected: []
    stdout: SplitParser {
      onRead: function (line) {
        var t = String(line).trim()
        if (t !== "" && conflictProc.collected.length < 200)
          conflictProc.collected = conflictProc.collected.concat([t])
      }
    }
    onExited: root.importConflicts = conflictProc.collected
  }

  // A hand-typed path also shows the conflicts, after a
  // pause in typing.
  Timer {
    id: conflictTimer
    interval: 500
    onTriggered: root.checkConflicts()
  }

  Process {
    id: importProc
    property string secret: ""
    stdinEnabled: true
    // Always write a line, even an empty one: the script reads exactly one and,
    // without it, would wait forever with the panel blocked.
    onStarted: {
      write(secret + "\n")
      secret = ""
    }
    stdout: SplitParser { onRead: function (line) { root.setStatus(String(line).trim(), false) } }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.setStatus(String(text).trim(), true)
    }
    onExited: function (code) {
      root.busy = false
      if (code !== 0 && !root.statusIsError) root.setStatus(root.tr.importFail, true)
      if (code === 0) {
        root.importPass = ""
        root.view = "list"
      }
      root.refresh()
    }
  }

  Process {
    id: syncProc
    command: [root.cmd, "menu-sync"]
    onExited: function (code) {
      root.busy = false
      root.setStatus(code === 0 ? root.tr.synced : root.tr.syncFail, code !== 0)
    }
  }

  Timer {
    interval: 300000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onOpenedChanged: {
    if (opened) {
      if (dialogPending) return
      // With a command running, the screen stays where it is to receive
      // its result.
      if (busy) return
      view = "list"
      filterText = ""
      search.text = ""
      cursorIndex = 0
      cursorActive = false
      armedDelete = ""
      setStatus("", false)
      refresh()
      if (probed && !langProc.running) langProc.running = true
      // contentHeight only settles after layout and after `upssh json`
      // returns; resetting before that does not stick and the list reopens where it was.
      topTimer.restart()
      Qt.callLater(function () { keyCatcher.forceActiveFocus() })
    } else if (!dialogPending) {
      armedDelete = ""
      armTimer.stop()
      // Closing the panel forgets passwords that were typed and not used.
      if (!busy) {
        fPassword = ""
        exportPass = ""
        importPass = ""
      }
    }
  }

  // ------------------------------------------------------------------ bar icon
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uf233"
    tooltipText: root.servers.length > 0
      ? root.tr.barTip + root.servers.length + root.tr.barTipServers
      : root.tr.title
    horizontalMargin: 8.5
    onPressed: function (code) {
      if (code === Qt.RightButton) root.syncMenu()
      else root.toggle()
    }
  }

  // ------------------------------------------------------------------ panel
  KeyboardPanel {
    id: panel
    bar: root.bar
    anchorItem: button
    owner: root
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(column.implicitHeight + footerRow.implicitHeight + Style.space(10), Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: search.activeFocus || root.view !== "list"

      onMoveRequested: function (dx, dy) {
        if (dy === 0) return
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy)
      }
      onActivateRequested: root.connectRow(root.currentRow)
      onDeleteRequested: root.requestDelete(root.currentRow)
      onCloseRequested: root.view === "list" ? root.close() : root.closeForm()
      onTabRequested: function (direction) { root.switchPanel(direction) }
      onTextKey: function (t) {
        if (t === "e") root.openForm(root.currentRow)
        else if (t === "n") root.openForm(null)
        else if (t === "r") root.refresh()
        else search.forceActiveFocus()
      }

      ColumnLayout {
        anchors.fill: parent
        spacing: Style.space(10)

      Flickable {
        id: panelFlick
        Layout.fillWidth: true
        Layout.fillHeight: true
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(10)

          PanelHero {
            width: parent.width
            title: root.view === "form"
              ? (root.fId === "" ? root.tr.newServer : root.tr.editServer)
              : root.view === "export" ? root.tr.exportTitle
              : root.view === "import" ? root.tr.importTitle
              : root.tr.title
            meta: root.view === "form"
              ? root.tr.formHint
              : root.view === "export"
              ? (root.exportWithSecrets ? root.tr.metaEncrypted : root.tr.metaPlain)
              : root.view === "import"
              ? (root.importFile === "" ? root.tr.pickAFile : root.importFile)
              : root.servers.length + root.tr.servers + root.groupNames.length + root.tr.groups
            detail: root.view === "list" && root.filterText !== "" ? root.flatRows.length + root.tr.visible : ""
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              Text {
                textFormat: Text.PlainText
                text: "\uf233"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.display
              }
            }
            trailingControl: Component {
              PanelActionButton {
                iconText: root.view === "list" ? "\uf067" : "\uf060"
                tooltipText: root.view === "list" ? root.tr.addTip : root.tr.backTip
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.view === "list" ? root.openForm(null) : root.closeForm()
              }
            }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.status !== ""
            width: parent.width
            text: root.status
            color: root.statusIsError ? root.urgent : root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          // ------------------------------------------------------- list
          Ui.TextField {
            id: search
            visible: root.view === "list"
            width: parent.width
            placeholderText: root.tr.filterPh
            foreground: root.foreground
            accent: root.accent
            font.family: root.fontFamily
            onTextChanged: {
              root.filterText = text
              root.cursorIndex = 0
              root.armedDelete = ""
            }
            Keys.onEscapePressed: {
              if (text !== "") text = ""
              else keyCatcher.forceActiveFocus()
            }
            Keys.onDownPressed: { keyCatcher.forceActiveFocus(); root.cursorActive = true }
            Keys.onReturnPressed: { keyCatcher.forceActiveFocus(); root.connectRow(root.currentRow) }
          }

          Text {
            textFormat: Text.PlainText
            visible: root.view === "list" && root.flatRows.length === 0
            width: parent.width
            text: root.servers.length === 0
              ? root.tr.emptyFirst
              : root.tr.emptyFilter
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Repeater {
            model: root.view === "list" ? root.sections : []

            Column {
              id: sectionCol
              required property var modelData
              required property int index
              // Rows share a single flat cursor, so each section has to add up
              // the ones before it; without the explicit id the delegate's
              // `parent.parent` does not reach here and every group started
              // at index 0, highlighting two rows at once.
              readonly property int offset: root.rowOffset(index)
              width: column.width
              spacing: Style.space(4)

              PanelSectionHeader {
                width: parent.width
                text: sectionCol.modelData.group + "  ·  " + sectionCol.modelData.rows.length
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              Repeater {
                model: sectionCol.modelData.rows
                ServerRow {
                  required property var modelData
                  required property int index
                  width: sectionCol.width
                  row: modelData
                  rowIndex: sectionCol.offset + index
                }
              }
            }
          }

          // ---------------------------------------------------------- form
          Column {
            visible: root.view === "form"
            width: parent.width
            spacing: Style.space(8)

            Field {
              width: parent.width
              label: root.tr.lName
              value: root.fName
              placeholder: root.tr.phName
              onEdited: function (v) { root.fName = v }
            }

            Dropdown {
              width: parent.width
              label: root.tr.lGroup
              value: root.fGroup
              options: {
                var out = []
                for (var i = 0; i < root.groupNames.length; i++)
                  out.push({ label: root.groupNames[i], value: root.groupNames[i] })
                out.push({ label: root.tr.newGroupOpt, value: root.newGroupSentinel })
                return out
              }
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onChanged: function (v) { root.fGroup = v }
            }

            Field {
              visible: root.fGroup === root.newGroupSentinel
              width: parent.width
              label: root.tr.lNewGroup
              value: root.fNewGroup
              placeholder: root.tr.phNewGroup
              onEdited: function (v) { root.fNewGroup = v }
            }

            Field {
              width: parent.width
              label: root.tr.lHost
              value: root.fHost
              placeholder: root.tr.phHost
              onEdited: function (v) { root.fHost = v }
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Field {
                Layout.preferredWidth: Style.space(110)
                label: root.tr.lPort
                value: root.fPort
                placeholder: "22"
                onEdited: function (v) { root.fPort = v }
              }

              Field {
                Layout.fillWidth: true
                label: root.tr.lUser
                value: root.fUser
                placeholder: "root"
                onEdited: function (v) { root.fUser = v }
              }
            }

            Dropdown {
              width: parent.width
              label: root.tr.lAuth
              value: root.fAuth
              options: [
                { label: root.tr.authKey, value: "key" },
                { label: root.tr.authPass, value: "password" }
              ]
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onChanged: function (v) { root.fAuth = v }
            }

            Field {
              visible: root.fAuth === "key"
              width: parent.width
              label: root.tr.lIdentity
              value: root.fIdentity
              placeholder: root.tr.phIdentity
              onEdited: function (v) { root.fIdentity = v }
            }

            Field {
              visible: root.fAuth === "password"
              width: parent.width
              label: root.fId === "" ? root.tr.lPass : root.tr.lPassKeep
              value: root.fPassword
              placeholder: root.tr.phPass
              secret: true
              onEdited: function (v) { root.fPassword = v }
            }

            Field {
              width: parent.width
              label: root.tr.lOptions
              value: root.fOptions
              placeholder: "-oHostKeyAlgorithms=+ssh-rsa"
              onEdited: function (v) { root.fOptions = v }
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Ui.Button {
                text: root.busy ? root.tr.saving : root.tr.save
                enabled: !root.busy
                bordered: true
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.saveForm()
              }

              Ui.Button {
                text: root.tr.cancel
                foreground: root.dim
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.closeForm()
              }

              Item { Layout.fillWidth: true }
            }
          }
          // -------------------------------------------------------- export
          Column {
            visible: root.view === "export"
            width: parent.width
            spacing: Style.space(10)

            Toggle {
              width: parent.width
              label: root.tr.inclSecrets
              description: root.tr.inclSecretsDesc
              checked: root.exportWithSecrets
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: { root.exportWithSecrets = !root.exportWithSecrets; root.retargetExport() }
            }

            Field {
              visible: root.exportWithSecrets
              width: parent.width
              label: root.tr.lExportPass
              value: root.exportPass
              placeholder: root.tr.phExportPass
              secret: true
              onEdited: function (v) { root.exportPass = v }
            }

            Field {
              width: parent.width
              label: root.tr.lSaveTo
              value: root.exportPath
              placeholder: root.tr.phSaveTo
              onEdited: function (v) { root.exportPath = v; root.exportPathConfirmed = false }
            }

            Ui.Button {
              visible: root.hasZenity
              text: root.tr.browseSave
              iconText: "\uf07c"
              foreground: root.dim
              accent: root.accent
              fontFamily: root.fontFamily
              onClicked: root.browseExport()
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Ui.Button {
                text: root.busy ? root.tr.exporting : root.tr.doExport
                enabled: !root.busy
                bordered: true
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.runExport()
              }

              Ui.Button {
                text: root.tr.cancel
                foreground: root.dim
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.closeForm()
              }

              Item { Layout.fillWidth: true }
            }
          }

          // -------------------------------------------------------- import
          Column {
            visible: root.view === "import"
            width: parent.width
            spacing: Style.space(10)

            Field {
              width: parent.width
              label: root.tr.lImportFile
              value: root.importFile
              placeholder: root.tr.phImportFile
              onEdited: function (v) { root.importFile = v; conflictTimer.restart() }
            }

            Field {
              visible: root.importFile.endsWith(".gpg")
              width: parent.width
              label: root.tr.lFilePass
              value: root.importPass
              placeholder: root.tr.phFilePass
              secret: true
              onEdited: function (v) { root.importPass = v }
            }

            Text {
              textFormat: Text.PlainText
              width: parent.width
              visible: root.importConflicts.length > 0
              text: root.tr.alreadyHere + root.importConflicts.join(", ")
              color: root.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            Dropdown {
              width: parent.width
              label: root.tr.lPolicy
              value: root.importPolicy
              options: [
                { label: root.tr.pKeep, value: "manter" },
                { label: root.tr.pReplace, value: "substituir" },
                { label: root.tr.pCopy, value: "copiar" }
              ]
              foreground: root.foreground
              accent: root.accent
              fontFamily: root.fontFamily
              onChanged: function (v) { root.importPolicy = v }
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              Ui.Button {
                text: root.busy ? root.tr.importing : root.tr.doImport
                enabled: !root.busy && root.importFile !== ""
                bordered: true
                foreground: root.foreground
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.runImport()
              }

              Ui.Button {
                visible: root.hasZenity
                text: root.tr.browse
                foreground: root.dim
                accent: root.accent
                fontFamily: root.fontFamily
                onClicked: root.browseImport()
              }

              Item { Layout.fillWidth: true }
            }
          }

        }
      }

      // Outside the Flickable: with 22 servers the list pushed these buttons
      // below the fold, and export ended up hidden.
      RowLayout {
        id: footerRow
        visible: root.view === "list"
        Layout.fillWidth: true
        spacing: Style.space(8)

        Ui.Button {
          text: root.tr.doExport
          iconText: "\uf019"
          foreground: root.dim
          accent: root.accent
          fontFamily: root.fontFamily
          onClicked: root.openExport()
        }

        Ui.Button {
          text: root.tr.doImport
          iconText: "\uf093"
          foreground: root.dim
          accent: root.accent
          fontFamily: root.fontFamily
          onClicked: root.openImport()
        }

        Item { Layout.fillWidth: true }

        PanelActionButton {
          iconText: "\uf021"
          tooltipText: root.tr.syncTip
          foreground: root.dim
          fontFamily: root.fontFamily
          onClicked: root.syncMenu()
        }

        PanelActionButton {
          iconText: "\uf0ac"
          tooltipText: root.tr.langTip
          foreground: root.dim
          fontFamily: root.fontFamily
          onClicked: root.toggleLang()
        }

        PanelActionButton {
          iconText: "\uf084"
          tooltipText: root.tr.masterTip
          foreground: root.dim
          fontFamily: root.fontFamily
          onClicked: root.changeMaster()
        }
      }
      }
    }
  }


  // Ui.TextField has no label; this label+input pair gives the form the
  // same alignment as the Dropdown, which already draws its own.
  component Field: Column {
    id: field
    property string label: ""
    property string value: ""
    property string placeholder: ""
    property bool secret: false
    signal edited(string v)

    spacing: Style.spacing.labelGap

    Text {
      textFormat: Text.PlainText
      visible: field.label !== ""
      text: field.label
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Ui.TextField {
      width: field.width
      text: field.value
      password: field.secret
      placeholderText: field.placeholder
      foreground: root.foreground
      accent: root.accent
      font.family: root.fontFamily
      onTextChanged: field.edited(text)
    }
  }

  // One row per server: the name is the anchor, the destination sits below and
  // the actions only appear when the mouse or the cursor passes over it.
  component ServerRow: CursorSurface {
    id: serverRow
    property var row: null
    property int rowIndex: 0

    readonly property bool armed: root.armedDelete === String(row ? row.id : "")
    readonly property bool hot: hasCursor || rowHover.containsMouse

    hasCursor: root.cursorActive && root.cursorIndex === rowIndex
    foreground: root.foreground
    accent: root.accent
    implicitHeight: rowBody.implicitHeight + Style.space(12)

    MouseArea {
      id: rowHover
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: root.setCursor(serverRow.rowIndex)
      onClicked: root.connectRow(serverRow.row)
    }

    RowLayout {
      id: rowBody
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(8)
      spacing: Style.space(10)

      // Rail: solid when access is by stored password, faint when by key.
      Rectangle {
        Layout.preferredWidth: Style.space(3)
        Layout.preferredHeight: rowBody.implicitHeight
        radius: width
        color: serverRow.armed ? root.urgent : root.accent
        opacity: serverRow.row && serverRow.row.auth === "password" ? 0.9 : 0.4
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: serverRow.row ? String(serverRow.row.name) : ""
          color: serverRow.armed ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.subtitle
          elide: Text.ElideRight
        }

        Text {
          textFormat: Text.PlainText
          Layout.fillWidth: true
          text: serverRow.row
            ? serverRow.row.user + "@" + serverRow.row.host + ":" + serverRow.row.port
            : ""
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      // Only password access gets a mark; key is the normal case and the rail
      // on the left already tells them apart without filling the row with icons.
      Text {
        textFormat: Text.PlainText
        visible: !serverRow.hot && serverRow.row && serverRow.row.auth === "password"
        text: "\uf084"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }

      PanelActionButton {
        visible: serverRow.hot
        iconText: "\uf044"
        tooltipText: root.tr.editTip
        foreground: root.foreground
        fontFamily: root.fontFamily
        onClicked: root.openForm(serverRow.row)
      }

      PanelActionButton {
        visible: serverRow.hot
        iconText: "\uf1f8"
        tooltipText: serverRow.armed ? root.tr.confirmAgain : root.tr.removeTip
        foreground: serverRow.armed ? root.urgent : root.foreground
        fontFamily: root.fontFamily
        onClicked: root.requestDelete(serverRow.row)
      }
    }
  }
}
