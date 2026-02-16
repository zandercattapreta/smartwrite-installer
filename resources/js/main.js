// Main Logic
let plugins = [];
let selectedPlugins = new Set();
let selectedVault = "";

// Initialize
Neutralino.init();

// Events
Neutralino.events.on("windowClose", () => {
    Neutralino.app.exit();
});

document.addEventListener('DOMContentLoaded', async () => {
    await loadPlugins();
    await loadVaults();
});

// 1. Load Plugins
async function loadPlugins() {
    const list = document.getElementById('plugin-list');
    list.innerHTML = '<div style="padding: 20px;">Loading index...</div>';

    try {
        // Try local first -> then remote
        let pluginsData;
        try {
            // Read local plugins.json if running from source/dev
            // In prod, simple http request to github
            let response = await fetch('https://raw.githubusercontent.com/zandercpzed/smartwrite-installer/main/plugins.json');
            if (!response.ok) throw new Error('Network response was not ok');
            pluginsData = await response.json();
        } catch (e) {
            console.error(e);
            list.innerHTML = 'Failed to load plugins. Check connection.';
            return;
        }

        plugins = pluginsData;
        renderPlugins();
    } catch (err) {
        debugLog("Error loading plugins: " + err);
    }
}

function renderPlugins() {
    const list = document.getElementById('plugin-list');
    list.innerHTML = '';

    plugins.forEach((p, index) => {
        const card = document.createElement('div');
        card.className = 'card';
        card.onclick = (e) => togglePlugin(index, card);
        card.innerHTML = `
            <div class="card-header">
                <h3 class="card-title">${p.name}</h3>
                <div class="checkbox"></div>
            </div>
            <p class="card-desc">${p.description}</p>
        `;
        list.appendChild(card);
    });
}

function togglePlugin(index, cardElement) {
    if (selectedPlugins.has(index)) {
        selectedPlugins.delete(index);
        cardElement.classList.remove('selected');
    } else {
        selectedPlugins.add(index);
        cardElement.classList.add('selected');
    }
}

// 2. Load Vaults
async function loadVaults() {
    const select = document.getElementById('vault-select');
    select.innerHTML = '<option disabled>Scanning...</option>';

    try {
        let configPath = await Neutralino.os.getEnv("HOME");
        configPath += "/Library/Application Support/obsidian/obsidian.json";

        let vaults = [];
        
        // Read obsidian.json
        let output = await Neutralino.filesystem.readFile(configPath);
        let config = JSON.parse(output);
        
        if (config.vaults) {
            for (let key in config.vaults) {
                vaults.push(config.vaults[key].path);
            }
        }

        if (vaults.length > 0) {
            select.innerHTML = '<option value="" disabled selected>Select a Vault</option>';
            vaults.forEach(v => {
                const opt = document.createElement('option');
                opt.value = v;
                opt.textContent = v.split('/').pop() + ` (${v})`;
                select.appendChild(opt);
            });
        } else {
            select.innerHTML = '<option disabled>No vaults found automatically</option>';
        }

        select.onchange = (e) => { selectedVault = e.target.value; };

    } catch (err) {
        debugLog("Error finding vaults: " + err);
        select.innerHTML = '<option disabled>Could not read Obsidian config</option>';
    }
}

async function manualSelectVault() {
    let entry = await Neutralino.os.showOpenDialog('Select Vault Folder', {
        isDirectory: true
    });
    console.log(entry);
    if (entry && entry.length > 0) {
        selectedVault = entry[0];
        // Add to select and select it
        const select = document.getElementById('vault-select');
        const opt = document.createElement('option');
        opt.value = selectedVault;
        opt.textContent = selectedVault.split('/').pop() + " (Manual)";
        opt.selected = true;
        select.appendChild(opt);
    }
}

// 3. Install
async function installSelected() {
    if (!selectedVault) {
        showStatus("Please select a Vault first!");
        return;
    }
    if (selectedPlugins.size === 0) {
        showStatus("Select at least one plugin.");
        return;
    }

    showStatus("Installing...", true);
    
    // Create plugins dir
    let pluginDir = selectedVault + "/.obsidian/plugins";
    // Ensure dir exists
    await Neutralino.os.execCommand(`mkdir -p "${pluginDir}"`);

    for (let idx of selectedPlugins) {
        let p = plugins[idx];
        let targetPath = pluginDir + "/" + p.id;
        
        showStatus(`Installing ${p.name}...`);
        
        // Check if exists
        try {
            await Neutralino.filesystem.getStats(targetPath);
            // Exists -> Pull
            await Neutralino.os.execCommand(`cd "${targetPath}" && git pull`);
        } catch (e) {
            // Not exists -> Clone
            await Neutralino.os.execCommand(`git clone "${p.repo_url}" "${targetPath}"`);
        }
    }

    showStatus("Installation Complete! Restart Obsidian.", false, 5000);
}

// Utils
function showStatus(msg, persistent = false, timeout = 3000) {
    const el = document.getElementById('status-message');
    el.textContent = msg;
    el.classList.add('visible');
    
    if (!persistent) {
        setTimeout(() => {
            el.classList.remove('visible');
        }, timeout);
    }
}

function debugLog(msg) {
    console.log(msg);
    // Neutralino.debug.log(msg);
}
