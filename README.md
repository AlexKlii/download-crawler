# Download Crawler Script

## Overview

This PowerShell script is designed to automate the process of downloading ROMs for various gaming platforms. It processes multiple input files containing game titles, collects source URLs from the user, and then crawls public sites to download files whose link text matches the provided entries. The downloads are organized into subfolders named after each input file.

## Prerequisites

- **PowerShell 7.0 or higher**: This script requires PowerShell 7.0 or later. Ensure you have the correct version installed before running the script. You can download PowerShell 7.0 from the [official PowerShell GitHub page](https://github.com/PowerShell/PowerShell).

## Usage

### Step 1: Prepare Input Files

1. **Create Input Files**: Place your input files in the `./roms-lists` folder. Each file should be a `.txt` file containing a list of game titles, one title per line.
   
2. **Naming Conventions**:
   - **File Names**: Name your input files according to the platform (e.g., `gb.txt` for Game Boy, `gba.txt` for Game Boy Advance...).
   - **Content**: Each line in the input file should contain a single game title. The title should be as close as possible to the original game name to ensure accurate matching.

### Step 2: Run the Script

1. **Open PowerShell**: Launch PowerShell 7.0 or higher.

2. **Navigate to Script Directory**: Use the `cd` command to navigate to the directory where the script is located.

3. **Execute the Script**: Run the script by executing the following command:
   ```powershell
   .\rom-downloader.ps1
   ```

4. Follow the Prompts

### Step 3: Monitor the Download Process

- The script will display progress messages in the console, indicating which files are being downloaded and any errors that occur.
- Downloaded files will be organized into subfolders named after the input files (e.g., `gb`, `gba`).

### Step 4: Completion

- Once the script completes, you will see a message indicating that all operations are finished.
- The downloaded ROMs will be available in the subfolders within the destination folder you selected.

## Best Practices

### Input File Preparation

- **Single Title per Line**: Ensure that each line in the input file contains only one game title.
- **Original Game Names**: Use the most accurate and original game names to improve the chances of finding the correct ROMs.
- **Language Considerations**:
  - **English Titles**: Prefer English titles to maximize the chances of finding the ROMs, as many public sites use English names.
  - **Localized Titles**: If you want the ROM in a specific language (e.g., French), you can use the localized title. The script will prioritize versions based on language tags (e.g., `(France)`, `(Europe)`).

### URL Entry

- **Reliable Sources**: Enter URLs from reliable public sites that host ROMs. Ensure that the sites are legal and safe to use in your region.
- **Multiple URLs**: You can enter multiple URLs for each input file to increase the chances of finding all the ROMs.

### Cross-Checking

- **Avoid Duplicates**: Enable cross-checking to avoid downloading files that already exist in the destination folder. This saves time and bandwidth.

## Troubleshooting

- **No URLs Provided**: If you don't provide any URLs for an input file, the script will exit with an error message.
- **Failed Downloads**: If a download fails, the script will log the error and continue with the next file. Check the log for details on why the download failed.
- **No Input Files**: If no input files are found in the `./roms-lists` folder, the script will exit with an error message.

## Logging

- The script uses a logging module (`log-module.psm1`) to record its actions. Logs are useful for troubleshooting and tracking the script's progress.

### Log File Location
```
./logs/
├── 2024-04-20.log
├── 2024-04-21.log
└── ...
```

## Example

### Input File (`gb.txt`)
```
The Legend of Zelda: Link's Awakening
Super Mario Land
Pokemon Red
Pokemon Blue
```

### Running the Script
```powershell
.\rom-downloader.ps1
```

### Output
- The script will create a subfolder named `gb` in the selected destination folder.
- It will download the ROMs for the listed games and organize them in the `gb` folder.

## Conclusion

This script simplifies the process of downloading ROMs by automating URL collection, file matching, and downloading. By following the best practices outlined in this README, you can ensure a smooth and efficient experience.

**Enjoy your gaming! 🎮**