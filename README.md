# Eye Tracker Analyzer

Eye Tracker Analyzer is a MATLAB-based toolbox for segmenting, extracting, visualizing and analyzing oculomotor data. The toolbox was produced in order to enable researchers interested in exploring their eye movement data an ability to do so without requiring extensive expertise.

The toolbox:
- Implements an easy-to-use graphical user interface (GUI) for less code-experienced users
- Allows easy parsing and segmentation of oculomotor data
- Implements an adapted version of [Enbgert & Kliegl's (2003)](https://doi.org/10.1016/S0042-6989(03)00084-1) microsaccade detection algorithm, with all parameters customizable via GUI
- Visualizes saccade detection quality and allows semi-automatic editing of it
- Production of various oculomotor measures, including (micro)saccade rate, velocity, amplitudes, fixation durations, eye vergence and more
- Production of individual-level and group-level plots

The toolbox was developed and tested in [Prof. Shlomit Yuval-Greenberg's lab](https://people.socsci.tau.ac.il/mu/shlomitgreenberg/) by multiple authors (see credits).

## Minimal requirements
In order to run the toolbox, you should install:
- MATLAB version 2017b or later
- [Signal Processing Toolbox](https://uk.mathworks.com/products/signal.html)
- [Statistics and Machine Learning Toolbox](https://uk.mathworks.com/products/statistics.html)

Currently, the toolbox only operates on Windows OS (10 and up).

In order to use the auto-update functionality (see Staying up-to-date below), you need:
- [Git](https://github.com/git-guides/install-git)

## Installation

Download the .zip file or clone via git or GitHub Desktop

```bash
git clone https://github.com/coriumgit/eye-tracker-analyzer.git
```

## Usage

1. Start MATLAB
2. Navigate to the folder containing Eye Tracker Analyzer
3. Type eyeTrackerAnalyzer in MATLAB command prompt or run the script called eyeTrackerAnalyzer.m

## Staying up-to-date
To check for updates, type eyeTrackerAnalyzerEXE in the MATLAB command prompt or run the script called eyeTrackerAnalyzerEXE.m

The script will check your local repository against changes made in the master and offer to download the new version if available. Git must be installed locally in order to run this script.

NOTE: Any unsaved local changes will be overwritten!

## Contributing

Pull requests are welcome. For major changes, please open an issue first to discuss what you would like to change.

If forking, please cite the original work in any publication resulting from the adapted scripts.

## Please cite as
Tal-Perry, Solomon, Pakula, Shdeor & Yuval-Greenberg (in prep). Eye Tracker Analyzer: a GUI-based tool for microsaccade extraction and analysis.

## License

[GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html)

## Credits
Based on code written by Shlomit Yuval-Greenberg & Alon Keren. Additional contributions were made by Noam Tal-Perry, Omer Solomon, Dekel Abeles, Roy Amit, Orit Shdeor, and Bar Pakula.

This code includes code parts written by Ralf Engert and Olaf Dimigen.
