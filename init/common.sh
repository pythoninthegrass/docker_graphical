# Magenta
print_header() {
	echo -e "\e[35m**** ${*} ****\e[0m"
}

# Cyan
print_step_header() {
    echo -e "\e[36m  - ${*}\e[0m"
}

# Yellow
print_warning() {
    echo -e "\e[33mWARNING: ${*}\e[0m"
}

# Red
print_error() {
    echo -e "\e[31mERROR: ${*}\e[0m"
}
