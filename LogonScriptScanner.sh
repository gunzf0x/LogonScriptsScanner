#!/bin/bash


# Set colors to print
RED='\033[0;31m'
BRED='\033[1;31m'
BG_RED='\033[41m'
GREEN='\033[0;32m'
BGREEN='\033[1;32m'
YELLOW='\033[0;33m'
BYELLOW='\033[1;33m'
BLUE='\033[0;34m'
BBLUE='\033[1;34m'
PURPLE='\033[0;35m'
BPURPLE='\033[1;35m'
CYAN='\033[0;36m'
BCYAN='\033[1;36m'
GRAY='\033[0;37m'
BLACK='\e[30m'
NC='\033[0m' # No Color


# Set symbols to print
STAR=$(echo -en "${BCYAN}[${BPURPLE}*${BCYAN}]${NC}")
STAR_2=$(echo -en "${BBLUE}[${BGREEN}*${BBLUE}]${NC}")
SUCCESS_SYM=$(echo -en "${BYELLOW}[${BCYAN}+${BYELLOW}]${NC}")
WARNING=$(echo -en "${BRED}[${BYELLOW}-${BRED}]${NC}")
LENGTH_SEPARATOR=75
SEPARATOR=$(echo -e "\n${BCYAN}";for i in $(seq 1 $LENGTH_SEPARATOR); do echo -n "=" ; done; echo -e "\n${NC}")


# Message if user presses CTRL+C
trap ctrl_c INT

function ctrl_c() {
        echo -e "\n${WARNING} ${BRED}Ctrl+C. Exiting...${NC}"
        exit 1
}


# Banner
print_banner() {
    echo -e "${BRED} ____                                               ${NC}"
    echo -e "${BRED}|    |    ____   ____   ____   ____                 ${NC}"
    echo -e "${BRED}|    |   /  _ \ / ___\ /  _ \ /    \                ${NC}"
    echo -e "${BRED}|    |__(  <_> ) /_/  >  <_> )   |  \               ${NC}"
    echo -e "${BRED}|_______ \____/\___  / \____/|___|  /               ${NC}"
    echo -e "${BRED}        \/    /_____/             \/                ${NC}"
    echo -e "${BYELLOW}    _________             __        __           ${NC}"
    echo -e "${BYELLOW}   /   _____/ ___________|__|______/  |_  ______ ${NC}"
    echo -e "${BYELLOW}   \_____  \_/ ___\_  __ \  \____ \   __\/  ___/ ${NC}"
    echo -e "${BYELLOW}   /        \  \___|  | \/  |  |_> >  |  \___ \  ${NC}"
    echo -e "${BYELLOW}  /_______  /\___  >__|  |__|   __/|__| /____  > ${NC}"
    echo -e "${BYELLOW}          \/     \/         |__|             \/  ${NC}"
    echo -e "${BBLUE}  _________                                        ${NC}"
    echo -e "${BBLUE} /   _____/ ____ _____    ____   ____   ___________${NC}"
    echo -e "${BBLUE} \_____  \_/ ___\\\\__   \\  /    \\ /    \_/ __ \_  __ \ ${NC}"
    echo -e "${BBLUE} /        \  \___ / __ \|   |  \   |  \  ___/|  | \/${NC}"
    echo -e "${BBLUE}/_______  /\___  >____  /___|  /___|  /\___  >__|   ${NC}"
    echo -e "${BBLUE}        \/     \/     \/     \/     \/     \/       ${NC}"
    echo -e "                                          ${GRAY}by gunzf0x ${NC}"
    echo ""
    echo -e "A tool designed to scan and find potentially vulnerable Logon Scripts\nin Windows machines in Active Directory environments."
}

# Function to display usage information
help_usage_message() {
    echo -e "${WARNING} ${RED}Usage${NC}:${YELLOW}   $0 <username> <password> <domain> <dc-ip>${NC}"
    echo -e "    ${BLUE}Example${NC}:${YELLOW} $0 user123 pass456 contoso.local 10.10.100.200${NC}"
    exit 1
}

# Checks if user has provided needed arguments
process_args() {
    if [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]]; then
        help_usage_message
    fi
    USERNAME="$1"
    PASSWORD="$2"
    DOMAIN="$3"
    DC_IP="$4"
}

# Function to validate IPv4 address
validate_ip() {
    local ip="$1"
    if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        IFS='.' read -r -a octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if (( octet < 0 || octet > 255 )); then
                echo "Invalid IP address: $ip"
                exit 1
            fi
        done
    else
        echo -e "${WARNING} ${RED}Invalid IPv4 address format: ${YELLOW}$ip${NC}"
        echo -e "    ${RED}Valid format example: ${YELLOW}10.10.10.10${NC}"
        exit 1
    fi
}

# Check if needed binaries by this scripts are installed ("rpcclient", "smbcacls", "smbclient" and "bloodyAD")
check_if_needed_binaries_are_installed (){
    # Check if 'rpcclient' is installed
    if ! command -v rpcclient &> /dev/null; then
        echo -e "${WARNING} ${RED}Error: ${YELLOW}rpcclient${RED} is not installed or is not included in \$PATH variable.${NC}"
        echo -e "    ${YELLOW}Try to install it running ${BGREEN}sudo apt update -y && sudo apt install smbclient -y${YELLOW} and retry"
        exit 1
    fi
    # Check if 'smbcacls' is installed
    if ! command -v smbcacls &> /dev/null; then
        echo -e "${WARNING} ${RED}Error: ${YELLOW}smbcacls${RED} is not installed or is not included in \$PATH variable.${NC}"
        echo -e "    ${YELLOW}Try to install it running ${BGREEN}sudo apt update -y && sudo apt install smbclient -y${YELLOW} and retry"
        exit 1
    fi
    # Check if 'smbclient' is installed
    if ! command -v smbclient &> /dev/null; then
        echo -e "${WARNING} ${RED}Error: ${YELLOW}smbclient${RED} is not installed or is not included in \$PATH variable.${NC}"
        echo -e "    ${YELLOW}Try to install it running ${BGREEN}sudo apt update -y && sudo apt install smbclient -y${YELLOW} and retry"
        exit 1
    fi
    # Check if 'bloodyAD' is installed
    if ! command -v bloodyAD &> /dev/null; then
        echo -e "${WARNING} ${RED}Error: ${YELLOW}bloodyAD${RED} is not installed or is not included in \$PATH variable.${NC}"
        echo -e "    ${YELLOW}Try to install it with Python3 running ${BGREEN}pip3 install bloodyAD${YELLOW} or ${BGREEN}pip3 install bloodyAD --break-system-packages${YELLOW} ${BRED}(this last command under your own risk)${YELLOW} and retry"
        exit 1
    fi
}


# Function to display info provided as positional arguments
display_info(){
    echo -e "${SEPARATOR}"
    echo -e "${STAR} ${RED}Username${NC}: $1"
    echo -e "${STAR} ${RED}Password${NC}: $2"
    echo -e "${STAR} ${RED}Domain${NC}:   $3"
    echo -e "${STAR} ${RED}DC IP${NC}:    $4"
    echo -e "${SEPARATOR}"
    
}


# Get domain users using 'rpcclient'
get_domain_users(){
    echo -e "${SEPARATOR}"
    echo -e "${STAR} Attempting to get users through RPC..."
    # First, check that the credentials given are correct
    local rpcclient_login=$(rpcclient -U "$1%$2" "$3" -c 'exit' 2>&1)
    if echo -n $rpcclient_login | grep -q 'Cannot connect to server' ; then
        echo -e "${WARNING} ${RED}Invalid credentials (${YELLOW}${1}${RED}:${YELLOW}${2}${RED}). Please check and try again.${NC}"
        exit 1
    fi
    # Once we have checked our credentials are valid, request users from the domain
    rpcclient_command=$(rpcclient -U "$1%$2" $3 -c 'enumdomusers' | grep -o '\[.*\]' | sed 's/\[//;s/\]//' | awk -F 'rid' '{print $1}' 2>&1)
    # Second, save domain users obtained in a temporary file (located at /tmp), using date as timestamp
    local temp_usersdomain_file="/tmp/domain_users_$(date +%d_%m_%Y_%H%M%S).txt"
    echo "$rpcclient_command" | tr ' ' '\n' | sed '/^$/d' > $temp_usersdomain_file
    echo -e "${STAR} ${GREEN}Domain user list saved to: ${PURPLE}$temp_usersdomain_file${NC}"
}


# Check, if available, 'NETLOGON' share folders using 'smbclient' and check their permissions with 'smbcacls'
get_NETLOGON_shares(){
    echo -e "${STAR} ${BLUE}Attempting to get ${YELLOW}'${RED}NETLOGON${YELLOW}'${BLUE} share content at ${PURPLE}$3${BLUE}...${NC}"
    # Get directories at NETLOGON share. Hoping none of them has spaces...
    local netlogon_shares=$(smbclient //$3/NETLOGON -U $1%"$2" -c "ls" | sed '1,2d' | head -n -2 | awk '{print $1}')
    local shares_number=$(echo "$netlogon_shares" | wc -l)
    echo -e "\n${STAR} ${GREEN}Obtained ${YELLOW}${shares_number}${GREEN} folders within ${YELLOW}'${RED}NETLOGON${YELLOW}'${GREEN}:${NC}\n"
    for share in $netlogon_shares; do
        echo -e "${STAR_2} ${GREEN}${share}${NC}"
    done
    # Check NETLOGON directories permissions with 'smbcacls'
    echo -e "${SEPARATOR}"
    echo -e "${STAR}${GREEN} Checking permissions over folders located at ${YELLOW}'${RED}NETLOGON${YELLOW}'${GREEN} share...\n"
    counter=1
    for share in $netlogon_shares; do
        echo -e "${STAR_2} Checking interesting permissions over ${YELLOW}'${RED}${share}${YELLOW}'${NC} folder (${counter}/${shares_number})"
        local smbcacls_command=$(smbcacls //$3/NETLOGON /$share -U $1%"$2")
        # Uncomment the following lines if you do want to see permissions content
        # echo -ne $PURPLE 
        # printf "%s\n" "${smbcacls_command}"
        # echo -ne $NC
        local complete_command=$(printf "%s\n" "${smbcacls_command}")
        local filtered_command=$(printf "%s\n" "${complete_command}" | grep -E '^ACL')
        echo "$filtered_command" | while IFS= read -r line_share; do
             local owner=$(echo $line_share | awk -F 'I/' '{print $1}' | awk -F '\' '{print $2}' | awk -F ':' '{print $1}')
             local folder_permission=$(echo $line_share | awk -F 'I/' '{print $NF}')
             if ! echo $owner | grep -qi "Administrator" && echo "$folder_permission" | grep -q "W"; then
                 echo -e "\n${SUCCESS_SYM}${GREEN} User ${YELLOW}$owner${GREEN} can write at ${YELLOW}'NETLOGON/$share'${GREEN} folder${NC}\n"
             fi
        done
    ((counter++))
    done
}


# Get logon scripts for different users using bloodyAD. If we find one, check its permissions
get_logon_scripts(){
    echo -e "${SEPARATOR}"
    echo -e "${STAR} ${GREEN}Enumerating if any of the detected users has set ${RED}scriptPath${GREEN}${NC}\n"
    local cleaned_rpcclient_command=$(printf "%s\n" "${rpcclient_command}" | grep -vE 'Administrator|krbtgt|DefaultAccount|Guest')
    for user in $(echo $cleaned_rpcclient_command); do
       echo -e "${STAR_2} Attempting to get logon scripts for '$user' user..."
       local bloodyAD_command=$(bloodyAD --host $4 -d $3 -u $1 -p $2 get object $user --attr scriptPath)
       if echo $bloodyAD_command | grep -q "scriptPath"; then
           local scriptPath=$(echo $bloodyAD_command | grep "scriptPath" | tail -n 1 | awk -F 'scriptPath: ' '{print $2}' | sed 's/^[^\\]*\\[^\\]*\\[^\\]*\\[^\\]*\\//')
           echo -e "\n${SUCCESS_SYM}${GREEN} User ${YELLOW}$user${GREEN} has ${RED}scriptPath${GREEN} set: ${YELLOW}${scriptPath}${NC}\n"
           local modified_scriptPath=$(echo $scriptPath | tr '\\' '/')
           echo -e "${STAR_2}${GREEN} Checking permissions of ${YELLOW}${scriptPath}${GREEN} object..."
           local smbcacls_command=$(smbcacls //${4}/NETLOGON $modified_scriptPath -U $1%"$2")
           local complete_command=$(printf "%s\n" "${smbcacls_command}")
           local filtered_command=$(printf "%s\n" "${complete_command}" | grep -E '^ACL')
           echo "$filtered_command" | while IFS= read -r line_share; do
               local owner=$(echo $line_share | awk -F 'I/' '{print $1}' | awk -F '\' '{print $2}' | awk -F ':' '{print $1}')
               local folder_permission=$(echo $line_share | awk -F 'I/' '{print $NF}')
               if ! echo $owner | grep -qi "Administrator" && echo "$folder_permission" | grep -q "W"; then
                 echo -e "\n${SUCCESS_SYM}${GREEN} User ${YELLOW}$owner${GREEN} can write at ${YELLOW}'NETLOGON/$modified_scriptPath'${GREEN} folder${NC}\n"
               fi
           done
       fi
   done
}


main() {
    # Set timer
    start_time=$(date +%s)
    # Print banner
    print_banner
    # Checks that the user has provided needed arguments
    process_args "$@"
    # Check that needed binaries ('rpcclient', 'smbcacls', 'smbclient' and 'bloodyAD') are installed
    check_if_needed_binaries_are_installed
    # Checks that the provided argument for IPv4 (4th argument) is valid
    validate_ip $DC_IP
    # Display info given by the user through positional arguments
    display_info $USERNAME $PASSWORD $DOMAIN $DC_IP
    # Get folders inside 'NETLOGON' share using 'smbclient' and check their permissions with 'smbcacls'
    get_NETLOGON_shares $USERNAME $PASSWORD $DC_IP
    # Request domain users through RPC with rpcclient
    get_domain_users $USERNAME $PASSWORD $DC_IP
    # Get logon scripts for every identified user with bloodyAD
    get_logon_scripts $USERNAME $PASSWORD $DOMAIN $DC_IP
    # End timer
    end_time=$(date +%s)
    echo -e "${BPURPLE}"; for j in $(seq 1 $LENGTH_SEPARATOR); do echo -n '-'; done; echo -e "${NC}"
    echo -e "${STAR}${BGREEN} Scan completed in ${BRED}$((end_time - start_time))${BGREEN} seconds.${NC}"
    echo -e "${BGREEN}~Bye${NC}"
}


# Run the script
main "$@"
