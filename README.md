# Anomaly Mansion

A Roblox game: Dracula's mansion is now a bed and breakfast. Host guests by day, spot anomalies by night.

## One-time setup (on your computer)

1. Install [Git](https://git-scm.com/downloads) and [VS Code](https://code.visualstudio.com/).
2. Install Rojo: in VS Code, install the **Rojo** extension (it installs the Rojo CLI for you), or see https://rojo.space/docs/v7/getting-started/installation/.
3. Clone this repo: `git clone https://github.com/aaron-securemed-services/rblx-anomaly-mansion.git`
4. In Roblox Studio, open **Plugins → Manage Plugins**, search for **Rojo**, and install it. (Or install the plugin from the VS Code extension.)

## Every session

1. Open the repo folder in VS Code and run `git pull`.
2. Start the Rojo server: VS Code command palette → **Rojo: Start Server** (or `rojo serve` in a terminal).
3. In Studio, open your `AnomalyMansion` place, click the **Rojo** plugin button → **Connect**.
4. Press **Play**. The Output window should print `Anomaly Mansion server started`.

Scripts under `src/` sync into Studio. Build the world (parts, models, lighting) in Studio, and save/publish it there. Scripts live in this repo, not in the `.rbxl` file.

## Layout

| Folder | Studio location |
|---|---|
| `src/server` | ServerScriptService/Server |
| `src/client` | StarterPlayer/StarterPlayerScripts/Client |
| `src/shared` | ReplicatedStorage/Shared |
