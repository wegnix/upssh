import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import qs.Ui as Ui

// upSSH — um ícone na barra e um painel para ligar, cadastrar e editar
// servidores. Toda a gestão acontece aqui; o terminal só é aberto para a
// sessão SSH em si.
//
// Os dados vivem em ~/.config/upssh/servers.json e as senhas no cofre
// GPG ao lado; o painel nunca lhes toca directamente — fala sempre com o
// comando `upssh`, que é a única coisa que sabe cifrar e que mantém o
// menu do Omarchy sincronizado.
Panel {
  id: root
  moduleName: "wesley.upssh"
  ipcTarget: "upssh"
  manageIpc: true

  // O Panel base é um Item sem tamanho próprio: sem isto o botão da barra
  // fica com 0px e o widget não aparece.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // ------------------------------------------------------------------ estado
  property var servers: []
  property string filterText: ""
  property string view: "list" // "list" | "form"
  property string status: ""
  property bool statusIsError: false
  property string armedDelete: ""
  property int cursorIndex: 0
  property bool cursorActive: false
  property bool busy: false

  // campos do formulário
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

  // exportação / importação
  property bool exportWithSecrets: false
  property string exportPass: ""
  property string exportPath: ""
  property string importFile: ""
  property string importPass: ""
  property var importConflicts: []
  property string importPolicy: "manter"

  // O diálogo de ficheiros rouba o foco e o painel fecha-se; isto marca a
  // ida ao diálogo para o reabrir depois sem apagar o que já foi preenchido.
  property bool dialogPending: false


  // ------------------------------------------------------------- traduções
  // O idioma vem de `upssh lang`, para o painel e a linha de comandos
  // falarem sempre o mesmo.
  property string lang: "pt"

  // Quem instala com `omarchy plugin add` recebe o comando dentro da pasta do
  // plugin, fora do PATH; quem usa o install.sh tem-no em ~/.local/bin. Este
  // caminho cobre os dois, preferindo sempre o que veio com o plugin.
  readonly property string pluginDir: {
    var d = String(Qt.resolvedUrl("."))
    return d.indexOf("file://") === 0 ? d.substring(7) : d
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

  readonly property string newGroupSentinel: "\u0000novo"

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

  // Uma linha corresponde se o texto aparecer no nome, grupo, host ou login,
  // para "docker", "upnet" e "10.0.8" levarem todos ao mesmo sítio.
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

  // ------------------------------------------------------------------ acções
  function setStatus(text, isError) {
    root.status = String(text || "")
    root.statusIsError = !!isError
  }

  function refresh() {
    if (!loadProc.running) loadProc.running = true
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
    // O `bar` injectado expõe run() mas não shellQuote() — essa vive em
    // qs.Commons.Util, e chamá-la no objecto errado abortava a ligação toda.
    bar.run("omarchy-launch-tui --app-id=org.upssh " + Util.shellQuote(root.cmd) + " connect " + Util.shellQuote(String(row.id)))
    root.close()
  }

  function openForm(row) {
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

  function closeForm() {
    view = "list"
    fPassword = ""
    exportPass = ""
    importPass = ""
    setStatus("", false)
  }

  function effectiveGroup() {
    return fGroup === newGroupSentinel ? fNewGroup.trim() : fGroup
  }

  function saveForm() {
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
    if (!row) return
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

  // Alterna pt/en e grava a escolha, para a TUI e o menu irem atrás.
  function toggleLang() {
    var next = lang === "pt" ? "en" : "pt"
    langSetProc.command = [root.cmd, "lang", next]
    langSetProc.running = true
    lang = next
  }

  function changeMaster() {
    if (bar) bar.run(Util.shellQuote(root.cmd) + " master")
  }

  function defaultExportPath() {
    var stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-hhmm")
    return Quickshell.env("HOME") + "/upssh-" + stamp + (exportWithSecrets ? ".gpg" : ".json")
  }

  function openExport() {
    exportWithSecrets = false
    exportPass = ""
    exportPath = defaultExportPath()
    setStatus("", false)
    view = "export"
  }

  // A extensão acompanha o formato enquanto o utilizador não escolher um
  // caminho seu — depois disso manda o que ele escreveu.
  function retargetExport() {
    var want = exportWithSecrets ? ".gpg" : ".json"
    var other = exportWithSecrets ? ".json" : ".gpg"
    if (exportPath.endsWith(other)) exportPath = exportPath.slice(0, -other.length) + want
  }

  function runExport() {
    if (exportWithSecrets && exportPass.trim() === "") {
      setStatus(root.tr.needFilePass, true)
      return
    }
    root.busy = true
    setStatus("A exportar…", false)
    exportProc.collected = ""
    // A senha do ficheiro segue por stdin; o script lê-a de lá quando o
    // pedido não tem terminal, em vez de abrir um pinentry.
    exportProc.secret = exportWithSecrets ? exportPass : ""
    if (exportPath.trim() === "") {
      setStatus(root.tr.needDest, true)
      root.busy = false
      return
    }
    exportProc.command = exportWithSecrets
      ? [root.cmd, "export", "--com-senhas", "--stdin-pass", exportPath.trim()]
      : [root.cmd, "export", exportPath.trim()]
    exportProc.running = true
  }

  // Diálogo GTK do zenity: o selector do Omarchy depende de IPC com este
  // mesmo processo e não responde quando é o shell a invocá-lo.
  function openImport() {
    importFile = ""
    importPass = ""
    importConflicts = []
    importPolicy = "manter"
    setStatus("", false)
    // Abre só o ecrã: o caminho escreve-se à mão e o diálogo de ficheiros
    // fica atrás do botão "Procurar…", para quem o quiser.
    view = "import"
  }

  function browseImport() {
    setStatus(root.tr.choosingFile, false)
    dialogPending = true
    pickProc.collected = ""
    pickProc.running = true
  }

  function browseExport() {
    setStatus(root.tr.choosingDest, false)
    dialogPending = true
    savePickProc.collected = ""
    savePickProc.command = ["zenity", "--file-selection", "--save",
                            "--confirm-overwrite",
                            "--title=upSSH — guardar exportação",
                            "--filename=" + exportPath]
    savePickProc.running = true
  }

  // Volta a mostrar o painel depois do diálogo, com o que já lá estava.
  function afterDialog() {
    // A ordem importa: open() dispara onOpenedChanged na hora, e é a flag
    // ainda ligada que impede esse handler de limpar o formulário.
    if (!opened) open()
    dialogPending = false
  }

  function runImport() {
    if (importFile === "") return
    root.busy = true
    setStatus("A importar…", false)
    importProc.secret = importPass
    importProc.command = [root.cmd, "import", importFile,
                          "--conflito", importPolicy, "--stdin-pass"]
    importProc.running = true
  }

  function syncMenu() {
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

  // ---------------------------------------------------------------- processos
  // Lido no arranque e a cada abertura: o idioma pode ter mudado pela TUI.
  Component.onCompleted: probeProc.running = true

  // Uma leitura única no arranque decide qual dos dois caminhos usar.
  Process {
    id: probeProc
    command: ["test", "-x", root.pluginDir + "bin/upssh"]
    onExited: function (code) {
      root.bundled = code === 0
      langProc.running = true
      root.refresh()
    }
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

  Process {
    id: loadProc
    command: [root.cmd, "json"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(String(text || "{}"))
          root.servers = data.servers || []
        } catch (e) {
          root.servers = []
          root.setStatus(root.tr.readFail, true)
        }
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
      if (saveProc.pendingPassword !== "" && id !== "") {
        // A senha vai por stdin; nunca por argv, que é legível no `ps`.
        pwProc.secret = saveProc.pendingPassword
        saveProc.pendingPassword = ""
        pwProc.command = [root.cmd, "set-password", id]
        root.busy = true
        pwProc.running = true
        return
      }
      root.setStatus(root.tr.saved, false)
      root.closeForm()
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
      stdinEnabled = false
    }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.setStatus(String(text).trim(), true)
    }
    onExited: function (code) {
      root.busy = false
      if (code === 0) {
        root.setStatus(root.tr.savedVault, false)
        root.closeForm()
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
    onStarted: {
      if (secret !== "") write(secret + "\n")
      secret = ""
      stdinEnabled = false
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
              "--title=upSSH — importar servidores",
              "--filename=" + Quickshell.env("HOME") + "/",
              "--file-filter=Exportações do upSSH | *.json *.gpg",
              "--file-filter=Todos os ficheiros | *"]
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
      conflictProc.command = ["bash", "-c",
        "jq -r '.servers[].id' " + Util.shellQuote(file) +
        " 2>/dev/null | while read -r i; do jq -e --arg i \"$i\" '.servers[]|select(.id==$i)|.name' " +
        Util.shellQuote(Quickshell.env("HOME") + "/.config/upssh/servers.json") + " 2>/dev/null; done"]
      conflictProc.collected = []
      conflictProc.running = true
      root.afterDialog()
    }
  }

  // Um .gpg não se deixa inspeccionar sem senha, por isso a lista de
  // conflitos só aparece para ficheiros em claro; nos cifrados a escolha
  // aplica-se às cegas, como o utilizador a definir.
  Process {
    id: conflictProc
    property var collected: []
    stdout: SplitParser {
      onRead: function (line) {
        var t = String(line).trim().replace(/^"|"$/g, "")
        if (t !== "") conflictProc.collected = conflictProc.collected.concat([t])
      }
    }
    onExited: root.importConflicts = conflictProc.collected
  }

  Process {
    id: importProc
    property string secret: ""
    stdinEnabled: true
    onStarted: {
      if (secret !== "") write(secret + "\n")
      secret = ""
      stdinEnabled = false
    }
    stdout: SplitParser { onRead: function (line) { root.setStatus(String(line).trim(), false) } }
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: if (String(text || "").trim() !== "") root.setStatus(String(text).trim(), true)
    }
    onExited: function (code) {
      root.busy = false
      if (code !== 0 && !root.statusIsError) root.setStatus(root.tr.importFail, true)
      if (code === 0) root.view = "list"
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
      view = "list"
      filterText = ""
      cursorIndex = 0
      cursorActive = false
      armedDelete = ""
      setStatus("", false)
      refresh()
      if (!langProc.running) langProc.running = true
      // O contentHeight só assenta depois do layout e de o `upssh json`
      // voltar; repor antes disso não pega e a lista reabre onde ficou.
      topTimer.restart()
      Qt.callLater(function () { keyCatcher.forceActiveFocus() })
    } else if (!dialogPending) {
      armedDelete = ""
      armTimer.stop()
    }
  }

  // ------------------------------------------------------------ ícone da barra
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

  // ----------------------------------------------------------------- painel
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

          // ------------------------------------------------------ lista
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
              // As linhas partilham um único cursor plano, por isso cada secção
              // tem de somar as que vêm antes dela; sem o id explícito o
              // `parent.parent` do delegate não chega aqui e todos os grupos
              // começavam no índice 0, iluminando duas linhas ao mesmo tempo.
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

          // ---------------------------------------------------- formulário
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
          // ------------------------------------------------------ exportar
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
              onEdited: function (v) { root.exportPath = v }
            }

            Ui.Button {
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

          // ------------------------------------------------------ importar
          Column {
            visible: root.view === "import"
            width: parent.width
            spacing: Style.space(10)

            Field {
              width: parent.width
              label: root.tr.lImportFile
              value: root.importFile
              placeholder: root.tr.phImportFile
              onEdited: function (v) { root.importFile = v }
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

      // Fora do Flickable: com 22 servidores a lista empurrava estes botões
      // para baixo da dobra, e a exportação ficava escondida.
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


  // Ui.TextField não traz rótulo; este par rótulo+input dá ao formulário o
  // mesmo alinhamento que o Dropdown, que já desenha o seu.
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

  // Uma linha por servidor: o nome é a âncora, o destino fica por baixo e as
  // acções só aparecem quando o rato ou o cursor passam por cima.
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

      // Rail: cheio quando o acesso é por senha guardada, ténue por chave.
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

      // Só o acesso por senha ganha marca; a chave é o caso normal e o rail
      // à esquerda já o distingue sem encher a linha de ícones.
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
