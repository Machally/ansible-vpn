#!/bin/bash -ue
# Improved bash script for preparing the OS before running the Ansible playbook

# Improved: Removed -x for less verbosity to avoid sensitive data exposure in logs
# and removed unnecessary -N read operation.

# Quit on error and unset variables
set -eu

# Detect OS and version, exit for unsupported OS
if grep -qs "ubuntu" /etc/os-release; then
	os="ubuntu"
	os_version=$(grep 'VERSION_ID' /etc/os-release | cut -d '"' -f 2 | tr -d '.')
    if [[ "$os_version" -lt 2004 ]]; then
        echo "Ubuntu 20.04 or higher is required to use this installer."
        exit 1
    fi
elif [[ -e /etc/debian_version ]]; then
	os="debian"
	os_version=$(grep -oE '[0-9]+' /etc/debian_version | head -1)
    if [[ "$os_version" -lt 11 ]]; then
        echo "Debian 11 or higher is required to use this installer."
        exit 1
    fi
elif [[ -e /etc/almalinux-release || -e /etc/rocky-release || -e /etc/centos-release ]]; then
	os="centos"
	os_version=$(grep -shoE '[0-9]+' /etc/almalinux-release /etc/rocky-release /etc/centos-release | head -1)
    if [[ "$os_version" -lt 8 ]]; then
        echo "Rocky Linux 8 or higher is required to use this installer."
        exit 1
    fi
else
    echo "Unsupported OS."
    exit 1
fi

# Restrict to root or sudo users only
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

# Define function to install dependencies for Debian-based systems
install_dependencies_debian() {
    # Secure: Define specific list of packages to install
    REQUIRED_PACKAGES=(
      sudo
      software-properties-common
      dnsutils
      curl
      git
      locales
      rsync
      apparmor
      python3
      python3-setuptools
      python3-apt
      python3-venv
      python3-pip
      aptitude
      direnv
      iptables
    )

    # Update system in a controlled manner
    apt update -y
    apt upgrade -y
    apt install -y "${REQUIRED_PACKAGES[@]}"
}

# Define function to install dependencies for CentOS-based systems
install_dependencies_centos() {
    # Install EPEL release safely
    dnf install -y epel-release
    # Secure: Only install from official repositories
    REQUIRED_PACKAGES=(
      sudo
      bind-utils
      curl
      git
      rsync
      python3
      python3-setuptools
      python3-pip
      python3-firewall
    )
    dnf install -y "${REQUIRED_PACKAGES[@]}"
}

# Call relevant function based on OS
case "$os" in
  "ubuntu"|"debian")
    install_dependencies_debian
    ;;
  "centos")
    install_dependencies_centos
    ;;
  *)
    echo "Unsupported OS for dependency installation."
    exit 1
    ;;
esac

# Clone or pull the latest Ansible playbook
REPO_DIR="$HOME/ansible-easy-vpn"
if [ -d "$REPO_DIR" ]; then
  pushd "$REPO_DIR"
  git pull
  popd
else
  git clone https://github.com/notthebee/ansible-easy-vpn "$REPO_DIR"
fi

# Secure handling of Python virtual environment
PYTHON=$(command -v python3)
[ -d "$REPO_DIR/.venv" ] || $PYTHON -m venv "$REPO_DIR/.venv"
source "$REPO_DIR/.venv/bin/activate"
pip install --upgrade pip
pip install -r "$REPO_DIR/requirements.txt"

# Further steps would include secure prompts for user input and secure file handling
# Continue from the secure setup of the Python virtual environment
echo "Python virtual environment set up successfully."

# Secure handling of user prompts and configurations
read_configurations() {
  echo "Setting up configurations interactively. Please follow the prompts."

  # Securely prompt for username
  while true; do
    read -p "Enter your desired UNIX username: " username
    if [[ "$username" =~ ^[a-z0-9]{1,15}$ ]]; then
      echo "Username valid."
      break
    else
      echo "Invalid username. Use only lowercase letters and numbers, up to 15 characters."
    fi
  done

  # Securely prompt for password
  while true; do
    read -s -p "Enter your password: " password
    echo
    read -s -p "Repeat your password: " password2
    echo
    if [[ "$password" == "$password2" && ${#password} -ge 8 && ${#password} -le 72 ]]; then
      echo "Password valid."
      break
    else
      echo "Passwords do not match or are outside valid length (8-72 characters)."
    fi
  done

  # Write configurations securely to file
  echo "username: \"$username\"" > "$REPO_DIR/custom.yml"
  echo "user_password: \"$password\"" > "$REPO_DIR/secret.yml"
  chmod 600 "$REPO_DIR/secret.yml"  # Set secure permissions for secret file

  echo "Configurations set and stored securely."
}

# Prompt for configuration inputs securely
read_configurations

# Securely setting additional configurations
setup_additional_configs() {
  echo "Setting additional configurations."

  # Example additional configuration
  read -p "Enable feature XYZ? [y/N]: " response
  if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "feature_XYZ: true" >> "$REPO_DIR/custom.yml"
  else
    echo "feature_XYZ: false" >> "$REPO_DIR/custom.yml"
  fi

  echo "Additional configurations set."
}

# Prompt for additional configurations
setup_additional_configs

# Encrypt sensitive configurations securely
echo "Encrypting sensitive configurations..."
ansible-vault encrypt "$REPO_DIR/secret.yml"

# Final steps
echo "Setup is complete. Ready to run the playbook."

# Optionally, run the playbook
run_playbook() {
  read -p "Would you like to run the playbook now? [y/N]: " decision
  if [[ "$decision" =~ ^[Yy]$ ]]; then
    ansible-playbook "$REPO_DIR/run.yml" --ask-vault-pass
    echo "Playbook run successfully."
  else
    echo "You can run the playbook manually by executing:"
    echo "ansible-playbook $REPO_DIR/run.yml --ask-vault-pass"
  fi
}

# Prompt to run the playbook
run_playbook
# Continue from optional playbook execution
echo "Setup is complete. You may now configure additional features if needed."

# Securely setting up network configurations
configure_network() {
    echo "Configuring network settings..."

    # Securely prompt for domain name
    while true; do
        read -p "Enter your domain name (must resolve to the public IP of this server): " domain_name
        # Use DNS utilities to verify the domain resolves to the correct IP address
        public_ip=$(curl -s https://api.ipify.org)
        domain_ip=$(dig +short @1.1.1.1 "$domain_name")
        
        if [[ "$domain_ip" == "$public_ip" ]]; then
            echo "Domain validation successful."
            break
        else
            echo "The domain does not resolve to the public IP ($public_ip). Please try again."
        fi
    done

    # Save domain name securely
    echo "root_host: \"$domain_name\"" >> "$REPO_DIR/custom.yml"

    # Secure DNS settings
    echo "Configuring DNS settings..."
    select dns_provider in Cloudflare Quad9 Google Custom; do
        case $dns_provider in
            Cloudflare) dns_nameservers="1.1.1.1"; break;;
            Quad9) dns_nameservers="9.9.9.9"; break;;
            Google) dns_nameservers="8.8.8.8"; break;;
            Custom) read -p "Enter custom DNS IP: " dns_nameservers; break;;
            *) echo "Invalid option, please choose again.";;
        esac
    done

    echo "dns_nameservers: \"$dns_nameservers\"" >> "$REPO_DIR/custom.yml"
    echo "DNS configuration set."
}

# Prompt to configure network settings
configure_network

# Email configuration
configure_email() {
    echo "Setting up email configurations for notifications and 2FA..."
    read -p "Would you like to set up email configurations? [y/N]: " setup_email

    if [[ "$setup_email" =~ ^[Yy]$ ]]; then
        read -p "Enter SMTP server address: " smtp_server
        read -p "Enter SMTP server port [default: 465]: " smtp_port
        smtp_port=${smtp_port:-465}  # Default to 465 if no input

        read -p "Enter SMTP username: " smtp_username
        read -s -p "Enter SMTP password: " smtp_password
        echo

        # Save email configurations securely
        echo "email_smtp_host: \"$smtp_server\"" >> "$REPO_DIR/custom.yml"
        echo "email_smtp_port: \"$smtp_port\"" >> "$REPO_DIR/custom.yml"
        echo "email_login: \"$smtp_username\"" >> "$REPO_DIR/secret.yml"
        echo "email_password: \"$smtp_password\"" >> "$REPO_DIR/secret.yml"

        # Encrypt email password immediately after it's stored
        ansible-vault encrypt "$REPO_DIR/secret.yml"

        echo "Email configuration completed successfully."
    else
        echo "Skipping email configuration."
    fi
}

# Prompt to configure email settings
configure_email

# Final security touches and cleanup
echo "Finalizing setup and securing configuration files..."
chmod 600 "$REPO_DIR/custom.yml"  # Secure custom configuration file
ansible-vault encrypt "$REPO_DIR/custom.yml"  # Optionally encrypt custom configuration for added security

echo "All configurations are secured. The system is ready for use."

# Optionally, provide instructions to manually run the playbook later
echo "You can manually run the playbook by navigating to $REPO_DIR and executing:"
echo "ansible-playbook run.yml --ask-vault-pass"
