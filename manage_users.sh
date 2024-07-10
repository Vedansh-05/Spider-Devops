#!/bin/bash

# Function to create users
create_user() {
    local username=$1
    local group=$2
    local permissions=$3

    # Check if the user already exists
    if id "$username" &>/dev/null; then
        echo "User $username already exists. Skipping."
    else
        # Create user with specified group and home directory
        sudo useradd -m -d /home/$username -g $group $username

        # Set permissions for the user's home directory
        sudo chmod $permissions /home/$username
        sudo chown $username:$group /home/$username
    fi
}

# Function to setup directories and files for each user
setup_files() {
    local username=$1

    # Create projects directory and README.md file
    sudo -u $username mkdir -p /home/$username/projects
    echo "Welcome, $username!" | sudo -u $username tee /home/$username/projects/README.md >/dev/null
}

# Read usernames from usernames.csv and process each line
while IFS=',' read -r username group permissions; do
    create_user "$username" "$group" "$permissions"
    setup_files "$username"
done < usernames.csv

echo "User creation and setup completed."
