#!/bin/bash

USERNAMES="usernames.csv"
LOG_FILE="manage_users.log"
LAST_ACTIVE_FILE="last_active.log"
INACTIVE_THRESHOLD_DAYS=90 

# Function to log messages with timestamps
log_message() {
    local message=$1
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a $LOG_FILE
}

# Function to log user activity
update_last_active() {
    local username=$1
    grep -v "$username" > LAST_ACTIVE_FILE
    echo "$username $(date '+%Y-%m-%d')"
}

# Function to create users
create_user() {
    local username=$1
    local group=$2
    local permissions=$3

    if id "$username" &>/dev/null; then
        log_message "User $username already exists. Skipping."
    else
        
        # Check if group exists or not
        if ! getent group "$group" &>/dev/null; then
            sudo addgroup "$group"
        fi

        sudo adduser --home /home/$username --ingroup $group --disabled-password --gecos "" "$username" &>/dev/null

        sudo chmod $permissions /home/$username
        sudo chown $username:$group /home/$username
        log_message "User $username created with group $group and permissions $permissions."
        update_last_active "$username"
    fi
}

# Function to setup directories and files for each user
setup_files() {
    local username=$1

    sudo -u $username mkdir -p /home/$username/projects
    echo "Welcome, $username! some intro message here." | sudo -u $username tee /home/$username/projects/README.md &>/dev/null
    log_message "Projects directory and README.md created for user $username."
}

# Function to read and process the CSV file
process_csv() {
    while IFS=',' read -r username group permissions; do
        create_user "$username" "$group" "$permissions"
        setup_files "$username"
    done < $USERNAMES

    log_message "Processed usernames.csv file."
}

# Interactive mode for adding, deleting, or modifying users
interactive_mode() {
    echo "Interactive mode: Select an option:"
    echo "1) Add a user"
    echo "2) Delete a user"
    echo "3) Modify a user's permissions"
    echo "4) Exit"

    read -rp "Enter your choice: " choice

    case $choice in
        1)
            read -rp "Enter username: " username
            read -rp "Enter group: " group
            read -rp "Enter permissions: " permissions
            create_user "$username" "$group" "$permissions"
            setup_files "$username"
            ;;
        2)
            read -rp "Enter username to delete: " username
            sudo userdel -r $username
            log_message "User $username deleted."
            ;;
        3)
            read -rp "Enter username to modify: " username
            read -rp "Enter new permissions: " permissions
            sudo chmod $permissions /home/$username
            log_message "Permissions for user $username changed to $permissions."
            ;;
        4)
            echo "Exiting interactive mode."
            ;;
        *)  
            echo "Invalid choice. Exiting."
            ;;
    esac
}

# Function to check if a user is inactive based on threshold
is_inactive() {
    local username=$1
    local last_active_date=$(date -d "$2" '+%s')
    local current_date=$(date '+%s')

    local inactive_days=$(( (current_date - last_active_date) / (60 * 60 * 24) )) #Calculation and conversion from seconds to days

    if [ "$inactive_days" -ge "$INACTIVE_THRESHOLD_DAYS" ]; then
        return 0  # User is inactive
    else
        return 1  # User is active
    fi

}

# Function remove inactive users
cleanup_inactive_users(){
    local inactive_users=()

    # Check each users inactivity
    while IFS=$'\n' read -r username last_active_date;do
        if is_inactive "$username" "$last_active_date"; then
            inactive_users+=("$username")
        fi
    done < $LAST_ACTIVE_FILE

    # Remove inactive users
    for username in "${inactive_users[@]}"; do
        sudo userdel -r "$username"  # Remove the user and their home directory
        log_message "Inactive user $username has been disabled and removed."
    done
}

# Main script execution
if [[ $1 == "-i" ]]; then
    interactive_mode
elif [[ $1 == "-c" ]];then
    cleanup_inactive_users
    log_message "User cleanup process completed."
else
    process_csv
fi

log_message "Script execution completed."