# PowerShell Software Installation Manager

A comprehensive PowerShell script for Windows 11 that provides an interactive, hierarchical menu system for installing and managing software packages. This tool supports multiple installation methods including Winget, MSI, EXE, PowerShell modules, and includes powerful search capabilities for discovering new software.

## 🚀 Features

✅ **Hierarchical Navigation System**
- Main Categories → Subcategories → Software Selection
- Easy back navigation between levels
- Clear visual organization of software packages
- Paged display for large lists

✅ **Multiple Installation Methods**
- Winget packages (primary method) - with interactive installation UI
- MSI installers with passive mode (shows progress, allows customization)
- EXE installers with standard installation UI
- PowerShell modules from PowerShell Gallery
- PowerShell scripts from URLs
- GitHub releases with automatic asset detection

✅ **Interactive Installation Experience**
- **Non-silent installations** - you can choose installation paths and options
- Installation confirmation dialogs
- Progress tracking and real-time feedback
- Custom installation arguments support
- Installation location selection (for supported installers)

✅ **Search & Discovery**
- **Built-in search function** - Press "S" from main menu to search and add software
- Search Winget repositories for new software packages
- Search GitHub repositories for open-source tools
- **Automatic addition** to appropriate categories with guided category selection
- **Smart search results** - finds MemTest86, Steam, Double Commander, and thousands more
- **No manual JSON editing required** - everything is handled through the interface
- UTF-8 encoding support for international characters

✅ **User Experience**
- Interactive menu system with clear prompts
- Installation confirmation before proceeding
- Batch installation of multiple packages
- Progress tracking during installations
- Comprehensive error handling and logging
- **System inventory and export capabilities** - Press "0" to view installed software
- **Software audit tools** - Generate CSV reports of all installed software
- Automatic script directory detection (run from anywhere)
- **Non-destructive operation** - never modifies system without confirmation

## Software Categories

### 🔧 Development (6 subcategories, 30+ packages)
- **IDEs & Editors**: Visual Studio Code, Visual Studio 2022, IntelliJ IDEA, Notepad++, Sublime Text, PyCharm, Android Studio, Zed Editor
- **Version Control**: Git, GitHub Desktop, TortoiseGit, Sourcetree
- **Databases**: MySQL Workbench, DBeaver, PostgreSQL, MongoDB Compass
- **Runtime & Languages**: Python 3, Node.js, Java JDK 17, .NET SDK, Go, Rust
- **API & Tools**: Postman, Insomnia, Docker Desktop, Wireshark
- **PowerShell Modules**: Posh-Git, PowerShellGet, Az PowerShell

### 🌐 Internet & Communication (4 subcategories, 20+ packages)
### 🎵 Multimedia (4 subcategories, 20+ packages)
### 🎮 Gaming (4 subcategories, 15+ packages)
### 📊 Productivity (4 subcategories, 15+ packages)
### ⚙️ Utilities (4 subcategories, 45+ packages)
- **System Tools**: PowerToys, Process Monitor, TreeSize, CCleaner, Speccy, HWiNFO, CPU-Z, GPU-Z, **MemTest86**, Windows Terminal, PowerShell Core, and 15+ Stardock tools
- **File Management**: 7-Zip, WinRAR, Everything, FreeCommander, Double Commander
- **Security**: Malwarebytes, Bitdefender, KeePass, Bitwarden
- **Remote Access**: PuTTY, KiTTY, MobaXterm, TeamViewer, AnyDesk, Chrome Remote Desktop
### 🤖 AI & Machine Learning (5 subcategories, 25+ packages)
### 🔒 Ethical Hacking & Security Testing (10 subcategories, 70+ packages)

## 📋 Quick Start

### Installation
```powershell
# Clone the repository
git clone https://github.com/ddemott/SoftwareInstaller.git
cd SoftwareInstaller

# Set execution policy (if needed)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Run the script from any directory
.\SoftwareInstaller.ps1
```

### Basic Usage
```powershell
# Run the interactive menu system
.\SoftwareInstaller.ps1

# To search for new software (like MemTest86):
# 1. Run the script: .\SoftwareInstaller.ps1
# 2. Press "S" for "Search & add new software"
# 3. Enter your search term (e.g., "memtest")
# 4. Select from Winget or GitHub results
# 5. Choose category and confirm addition

# The script automatically detects its own directory for required files
# You can run it from anywhere - no need to change directory first
```

### Installation Modes

The script now uses **interactive installation modes** by default:

- **Winget**: Interactive mode - shows installation progress and allows customization
- **MSI**: Passive mode (`/passive`) - shows progress bar, allows some customization
- **EXE**: Standard installation UI - full installer interface
- **GitHub Releases**: Automatic detection and standard installation

This allows you to:
- Choose installation directories
- Customize installation options
- See installation progress
- Handle any prompts during installation

## Requirements

- **Windows 11** (or Windows 10 with compatible PowerShell)
- **PowerShell 5.1+** (comes with Windows)
- **Administrator privileges** (for software installation)
- **Internet connection** (for downloading packages)
- **Winget** (recommended, comes with Windows 11)

## Files

- `SoftwareInstaller.ps1` - Main script with hierarchical navigation system
- `software-categories.json` - Complete software catalog with all categories (250+ packages)
- `Tests/` - Directory containing all test and validation scripts
  - `simple-test.ps1` - Verification script for checking software catalog integrity
  - `test-suite.ps1` - Comprehensive test suite for all software categories
  - `validate.ps1` - Validation script for JSON structure and data integrity
  - `debug-search.ps1` - Debugging script for search functionality
- `getInstalledFiles.ps1` - System audit tool for generating installed software reports
- `installation_log_*.txt` - Generated installation logs (timestamped)
- `installed_software_*.json` - Exported software inventory (if requested)
- `AllInstalledSoftware_*.csv` - Complete system software audit reports

## 🔧 Installation Behavior

### How to Add Missing Software
**Don't manually edit JSON files!** Use the built-in search feature:
1. Run `.\SoftwareInstaller.ps1`
2. Press **"S"** for "Search & add new software"
3. Enter your search term (e.g., "memtest86", "steam")
4. Choose from Winget or GitHub search results
5. Select the appropriate category for the software
6. Confirm the addition - it's automatically added to your catalog!

**Recent Additions Made Easy:**
- ✅ MemTest86 - Memory testing tool (added via Custom URL)
- ✅ Steam games - Automatically detected from system
- ✅ Double Commander - File manager via Winget

### Winget Installations
- **Interactive mode** - Shows installation UI when available
- Accepts package and source agreements automatically
- Allows you to see progress and choose options

### MSI Packages  
- **Passive mode** (`/passive`) - Shows progress bar
- Allows basic customization options
- Non-blocking installation experience

### EXE Installers
- **Standard installation** - Full installer interface
- Complete control over installation options
- Choose installation directory and features

### GitHub Releases
- Automatic asset detection for Windows
- Supports .exe, .msi, and .zip files
- Creates desktop shortcuts for extracted applications
- Custom installation arguments supported

### PowerShell Modules
- Installs to current user scope
- Force installation with clobber allowed
- Verifies successful installation

## 🐛 Known Issues & Bug Reports

**🔍 See Active Issues:** Check our [GitHub Issues](https://github.com/yourusername/powershell-software-installer/issues) for current bugs and feature requests.

### Major Known Issues
1. **Search and Add**: ✅ **SOLVED** - You can easily add missing software using the built-in search ("S" from main menu)
2. **Software Auditing**: ✅ **AVAILABLE** - Use `getInstalledFiles.ps1` to generate complete system software reports
3. **Interactive Installations**: Some installers may still run in silent mode if they don't support interactive options
4. **GitHub API Rate Limits**: Search functionality may be temporarily limited after heavy use  
5. **Winget Dependency**: Script requires Winget to be installed and accessible
6. **Admin Rights**: Some installations require administrator privileges
7. **PowerShell Execution Policy**: Default Windows security settings may prevent script execution
8. **Installation Path Selection**: Not all installers support custom path selection (depends on the software)
9. **Some menus have text ANSI lines off**: Some ANSI text needs to be fixed and are not in alignment. Minor issue


## 📄 License

This project is licensed under the MIT License.

---

**Project Status**: ✅ COMPLETED & READY FOR USE

The PowerShell Software Installation Manager is fully functional with comprehensive search, installation, and management capabilities!
