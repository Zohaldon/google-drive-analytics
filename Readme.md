# Google Drive Data Collector

This Ruby project is designed to collect information about shared drives and their files on Google Drive using the Google Drive API. It's a helpful utility for gathering data and statistics about shared drives, their permissions, and the files they contain.

## Requirements

- Ruby version 3 or higher
- Bundler gem (for managing project dependencies)

## Installation

Before running the project, make sure you have Ruby 3 or a higher version installed on your system. You'll also need the Bundler gem for managing project dependencies.

To install the required gems, navigate to the project directory in your terminal and run:

```shell
bundle install
```

This command will install all the necessary gems specified in the project's Gemfile.

## Running the Project

Once you've installed the required gems, you can run the project using the following command:

```shell
ruby user_impersonation.rb
```

Running this command will execute the script that collects information about shared drives and their files from Google Drive. The collected data will be saved to JSON files for further analysis and reporting.

Make sure to replace the placeholder in the `user_impersonation.rb` script with your actual Google API access token if you haven't already done so.

## Usage

After running the script, you'll find JSON files in the project directory with collected data. These files contain information about shared drives and the files within them.

You can use this data for various purposes, such as generating reports, monitoring access, and analyzing Google Drive usage.

## License

This project is open-source and available under the [MIT License](LICENSE). You are free to use, modify, and distribute it as needed.

## Contributing

If you'd like to contribute to this project or report issues, please feel free to create a pull request or open an issue on the [GitHub repository](https://github.com/zohaldon).
