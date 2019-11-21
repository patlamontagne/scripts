#!/bin/bash
VERSION=1.0
# add the following alias
# alias wordpress='sudo bash ~/scripts/wordpress.sh'

# Private key path
SSH_KEY=~/.ssh/id_rsa
# Projects dir
PROJECT_DIR=/mnt/c/dev/www/
WIN_PROJECT_DIR=C:/dev/www/
# Hosts file path - set to `no` to skip
HOSTS_FILE=/mnt/c/WINDOWS/system32/drivers/etc/hosts
# Apache vhosts file path - set to `no` to skip
VHOSTS_FILE=no #/mnt/c/dev/etc/apache2/httpd.conf


# Defaults initialization
_positionals=()
_arg_sync=0

# Colors
yellow="\e[33m"
green="\e[32m"
white="\e[39m"
red="\e[31m"

die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}

begins_with_short_option()
{
	local first_option all_short_options
	all_short_options='heluv'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

print_help ()
{
	echo
	echo -e "Pat's \e[96mSuPeR aWeSoMe WoRdPrEsS tOoL ${yellow}v${VERSION}"
	echo
	echo -e "${yellow}Usage:"
	echo -e "    ${white}wordpress [directory] [options...]"
	echo
	echo -e "${yellow}Options:"
	echo -e "    ${green}[directory]                    ${white}The directory name of your project"
	echo -e "    ${green}-h,  --help                    ${white}Prints help"
	echo -e "    ${green}     --sync=staging|prod       ${white}Syncs plugins & uploads to remote"
}

parse_commandline ()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-h|--help)
				print_help
				exit 0
				;;
			--sync=*)
				_arg_sync="${_key##--sync=}"
				;;
			-s*)
				_arg_sync="${_key##-s}"
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_positionals+=("$1")
				;;
		esac
		shift
	done
}


handle_passed_args_count ()
{
	_required_args_string="'domain'"
	test ${#_positionals[@]} -ge 1 || _PRINT_HELP=yes die "FATAL ERROR: Not enough positional arguments - we require exactly 1 (namely: $_required_args_string), but got only ${#_positionals[@]}." 1
	test ${#_positionals[@]} -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect exactly 1 (namely: $_required_args_string), but got ${#_positionals[@]} (the last one was: '${_positionals[*]: -1}')." 1
}

assign_positional_args ()
{
	_positional_names=('_arg_domain' )

	for (( ii = 0; ii < ${#_positionals[@]}; ii++))
	do
		eval "${_positional_names[ii]}=\${_positionals[ii]}" || die "Error during argument parsing, possibly an Argbash bug." 1
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args


# wordpress <domain> --sync=prod|staging
if [[ $_arg_sync == 'prod' ]] || [[ $_arg_sync == 'staging' ]]
then
	# Loading env file
	env_file=${PROJECT_DIR}${_arg_domain}/.env.${_arg_sync}
	if [[ ! -f $env_file ]]
	then
		echo "${red}No ${yellow}$env_file${red}, aborting.${white}"
		exit
	fi
	source $env_file

	# sync local files to remote
	echo -e "${green}Syncing plugins & uploads to remote${white}"
	echo -e "User: ${yellow}${HOST_USER}${white}"
	echo -e "Host: ${yellow}${HOST_NAME}${white}"
	rsync -am -v -r --progress \
		--include='web/' \
		--include='web/app/' \
		--include='web/app/plugins/' \
		--include='web/app/uploads/' \
		--include='web/app/plugins/***' \
		--include='web/app/uploads/***' \
		--exclude='*' \
		-e "ssh -i ${SSH_KEY}" \
        "${PROJECT_DIR}${_arg_domain}/" \
		"${HOST_USER}@${HOST_NAME}:app/"
	die

# --sync validation
elif [[ $_arg_sync != 0 ]]
then
	echo -e "${red}Unknown ${green}--sync${red} argument. Use ${yellow}staging ${red}or${yellow} prod"
	die
fi 

# wordpress <domain>

# setup local env
HOSTS_ENTRY="127.0.0.1      $_arg_domain"
VHOSTS_ENTRY="
<VirtualHost *:80>
    DocumentRoot "${WIN_PROJECT_DIR}${_arg_domain}/web"
    ServerName $_arg_domain
    ServerAlias www.$_arg_domain
    ErrorLog "${WIN_PROJECT_DIR}httpd-logs/$_arg_domain-error_log"
    CustomLog "${WIN_PROJECT_DIR}httpd-logs/$_arg_domain-access_log" common
</VirtualHost>
"

# seteup hosts file
if [[ $HOSTS_FILE != no ]]
then
	echo -e "${green}Adding to hosts file:${white}"
	sudo -- sh -c "cat <<EOF >>${HOSTS_FILE}

${HOSTS_ENTRY}  # auto wordpress" 
	echo
	echo -e "${yellow}${HOSTS_ENTRY}${white}"
	echo
fi

# setup vhosts file
if [[ $VHOSTS_FILE != no ]]
then
	echo -e "${green}Adding to vhosts file:${white}"
	sudo -- sh -c "cat <<EOF >>${VHOSTS_FILE}

# auto wordpress ${VHOSTS_ENTRY}
	"
	echo -e "${yellow}${VHOSTS_ENTRY}${white}"
fi

# get boilerplate project
echo -e "${green}Cloning https://gitlab.com/arsenalweb/new-project.git${white}"
cd ${PROJECT_DIR}
git clone https://gitlab.com/arsenalweb/new-project.git $_arg_domain

# deleting useless files
cd $_arg_domain
rm -rf .git
rm -rf docs
rm readme.md
cp .env.example .env
cp web/.htaccess.dev web/.htaccess

# fin
echo
echo -e "---------"
echo -e "Don't forget to:"
echo -e "${yellow}Restart Apache"
echo -e "Complete .env file"