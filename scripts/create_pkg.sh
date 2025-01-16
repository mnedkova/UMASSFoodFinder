#!/bin/bash

echo "Executing create_pkg.sh..."

dir_name=lambda_dist_pkg/

if [ -d "$dir_name" ]; then rm -Rf $dir_name; fi

mkdir $dir_name

# Create and activate virtual environment...
python -m venv env_$function_name

source env_$function_name/bin/activate


# Installing python dependencies...
FILE=lambdas/scraper/requirements.txt

if [ -f "$FILE" ]; then
  echo "Installing dependencies..."
  echo "From: requirement.txt file exists..."
  pip install -r "$FILE"

else
  echo "Error: requirement.txt does not exist!"
fi

# Deactivate virtual environment...
deactivate

# Create deployment package...
echo "Creating deployment package..."

cp -r  env_$function_name/lib/python3.13/site-packages/* $dir_name

cp lambdas/scraper/index.py $dir_name

# Removing virtual environment folder...
echo "Removing virtual environment folder..."

rm -rf env_$function_name

echo "Finished script execution!"