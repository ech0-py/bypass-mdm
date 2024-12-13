#!/bin/bash

# Script to disable MDM/JAMF
# IMPORTANT: Run this only after disabling SIP in Recovery Mode
# WARNING: This will temporarily disable MDM management

# Exit on any error
set -e

# Function to check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo "Please run as root using sudo"
        exit 1
    fi
}

# Function to backup hosts file and add MDM blocks
configure_hosts() {
    echo "Backing up and configuring hosts file..."
    cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d)
    
    cat << 'EOF' >> /etc/hosts
0.0.0.0 iprofiles.apple.com
0.0.0.0 deviceenrollment.apple.com
0.0.0.0 mdmenrollment.apple.com
0.0.0.0 gdmf.apple.com
0.0.0.0 acmdm.apple.com
0.0.0.0 albert.apple.com
EOF
    echo "Hosts file updated"
}

# Function to create timestamped backup directories and move files
backup_and_move() {
    timestamp=$(date +%Y%m%d)
    echo "Creating backup directories with timestamp: $timestamp"
    
    # Create backup directories
    sudo mkdir -p /Library/Disabled_LaunchAgents_${timestamp}
    sudo mkdir -p /var/db/Disabled_ConfigurationProfiles_${timestamp}
    sudo mkdir -p /Library/Disabled_LaunchDaemons_${timestamp}
    sudo mkdir -p /Library/Security/Disabled_SecurityAgentPlugins_${timestamp}
    
    # Move LaunchAgents
    echo "Moving Launch Agents..."
    sudo mv /Library/LaunchAgents/com.jamf.* /Library/Disabled_LaunchAgents_${timestamp}/ 2>/dev/null || echo "No JAMF launch agents found"
    
    # Move Configuration Profiles
    echo "Moving Configuration Profiles..."
    sudo mv /var/db/ConfigurationProfiles/* /var/db/Disabled_ConfigurationProfiles_${timestamp}/ 2>/dev/null || echo "No configuration profiles found"
    
    # Rename JAMF and Munki directories
    echo "Renaming JAMF and Munki directories..."
    [ -d "/usr/local/jamf" ] && sudo mv /usr/local/jamf /usr/local/jamf.${timestamp}
    [ -d "/usr/local/munki" ] && sudo mv /usr/local/munki /usr/local/munki.${timestamp}
    [ -d "/Library/Application Support/JAMF" ] && sudo mv "/Library/Application Support/JAMF" "/Library/Application Support/JAMF.${timestamp}"
    
    # Move Launch Daemons
    echo "Moving Launch Daemons..."
    sudo mv /Library/LaunchDaemons/com.jamf.* /Library/Disabled_LaunchDaemons_${timestamp}/ 2>/dev/null || echo "No JAMF launch daemons found"
    
    # Move Security Agent Plugins
    echo "Moving Security Agent Plugins..."
    [ -d "/Library/Security/SecurityAgentPlugins/JamfAuthPlugin.bundle" ] && \
        sudo mv /Library/Security/SecurityAgentPlugins/JamfAuthPlugin.bundle /Library/Security/Disabled_SecurityAgentPlugins_${timestamp}/
    
    # Rename Sentinel if it exists
    [ -d "/Library/Sentinel" ] && sudo mv /Library/Sentinel "/Library/Sentinel.${timestamp}"
}

# Function to disable launch services
disable_services() {
    echo "Disabling launch services..."
    sudo launchctl disable system/com.apple.ManagedClient.enroll
    sudo launchctl disable system/com.jamf.management.daemon
}

# Function to verify changes
verify_changes() {
    timestamp=$(date +%Y%m%d)
    echo -e "\nVerifying changes..."
    
    echo "Checking for remaining JAMF Launch Agents:"
    sudo ls -la /Library/LaunchAgents/com.jamf.* 2>/dev/null || echo "No JAMF launch agents remaining"
    
    echo -e "\nChecking for remaining JAMF Launch Daemons:"
    sudo ls -la /Library/LaunchDaemons/com.jamf.* 2>/dev/null || echo "No JAMF launch daemons remaining"
    
    echo -e "\nChecking backup directories:"
    echo "Launch Agents backup:"
    sudo ls -la /Library/Disabled_LaunchAgents_${timestamp}
    echo -e "\nConfiguration Profiles backup:"
    sudo ls -la /var/db/Disabled_ConfigurationProfiles_${timestamp}
    echo -e "\nLaunch Daemons backup:"
    sudo ls -la /Library/Disabled_LaunchDaemons_${timestamp}

    echo -e "\nTesting JAMF connection:"
    if command -v jamf >/dev/null 2>&1; then
        sudo jamf checkJSSConnection || echo "JAMF connection check failed - this is expected if MDM was successfully disabled"
    else
        echo "JAMF binary not found - this is expected if MDM was successfully disabled"
    fi
}

# Main execution
echo "Starting MDM/JAMF disable process..."
check_root
configure_hosts
backup_and_move
disable_services
verify_changes

echo -e "\nMDM/JAMF disable process complete. Please reboot your system."
echo "IMPORTANT: To re-enable MDM management later, you will need to:"
echo "1. Restore the hosts file from backup"
echo "2. Move all files back from their timestamped backup locations"
echo "3. Re-enable SIP in Recovery Mode"
echo "Backup timestamp used: $(date +%Y%m%d)"
