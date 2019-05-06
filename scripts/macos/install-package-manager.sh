#!/bin/bash

# ------------------------------------------------------------------------------
# Dependency Check
# ------------------------------------------------------------------------------

echo "Checking dependencies..."

# Install Homebrew.
if [ -z $(command -v brew) ]; then
  echo -e "\033[31mHomebrew was not found.\033[39m"
  echo "Installing Homebrew, please wait..."

  /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"

  # Double check that Homebrew was installed.
  # If it was not installed properly, we do not want to continue the script.
  if [ -z $(command -v brew) ]; then
    echo -e "\033[31mThere was an error installing Homebrew." \
            "Homebrew is required to install the remaining dependencies.\033[39m"
    exit 1
  fi
else
  echo "Homebrew is already installed."
fi
