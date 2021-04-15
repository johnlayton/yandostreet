#####################################################################
# Init
#####################################################################

export V5_API_DEBUG=1

function v5-random-string () {
  cat /dev/urandom | base64 | tr -dc '0-9a-zA-Z' | head -c10
}

function v5-curl-flags () {
  case "${V5_API_DEBUG}" in
    0) echo "--silent" ;;
    1) echo "--verbose" ;;
  esac
}

function v5-stream () {
  jq -cn --stream 'fromstream(1|truncate_stream(inputs))'
}

function v5-fields () {
  local QUERY=""
  for FIELD in "${@}"; do
    QUERY="$QUERY \"${FIELD}\"  : .${FIELD},"
  done
  jq -r "{ ${QUERY} }"
}

function v5-token () {
  echo -n "${WHISPIR_API_TOKEN}"
}

function v5-auth () {
  echo -n "${WHISPIR_API_USER}:${WHISPIR_API_PASS}" | base64 -
}

function v5-get () {
  local TYP=${1:-""}
  local PTH=${2:-""}
  local QRY=${3:-""}

  if [[ -n "${PTH}" ]]; then
    PTH="/${PTH}"
  fi

  if [[ -n "${QRY}" ]]; then
    QRY="?${QRY}"
  fi

  curl $(v5-curl-flags) \
       --request GET \
       --header 'Accept: application/json' \
       --header "Authorization: Basic $(v5-auth)" \
       --header "x-api-key: $(v5-token)" \
       --header "Content-Type: application/vnd.whispir.${TYP}-v1+json" \
       --header "Accept: application/vnd.whispir.${TYP}-v1+json" \
       "${WHISPIR_API_ENDPOINT}${PTH}${QRY}"
}

function v5-post () {
  local TYP=${1:-""}
  local PTH=${2:-""}
  local DTA=${3:-"{}"}

  if [[ -n "${PTH}" ]]; then
    PTH="/${PTH}"
  fi

  curl $(v5-curl-flags)  \
       --request POST \
       --header 'Accept: application/json' \
       --header "Authorization: Basic $(v5-auth)" \
       --header "x-api-key: $(v5-token)" \
       --header "Content-Type: application/vnd.whispir.${TYP}-v1+json" \
       --header "Accept: application/vnd.whispir.${TYP}-v1+json" \
       --data-raw "${DTA}" \
       "${WHISPIR_API_ENDPOINT}${PTH}"
}

function v5 () {
  [[ $# -gt 0 ]] || {
    _v5::help
    return 1
  }

  local command="$1"
  shift

  (( $+functions[_v5::$command] )) || {
    _v5::help
    return 1
  }

  _v5::$command "$@"
}

function _v5 {
  local -a cmds subcmds
  cmds=(
    'help:Usage information'
    'debug:Enable debugging curl commands'
    'init:Initialisation information'
    'workspace:Manage Workspaces'
    'contact:Manage Contacts'
    'resource:Manage Resources'
    'message:Manage Messages'
  )

  if (( CURRENT == 2 )); then
    _describe 'command' cmds
  elif (( CURRENT == 3 )); then
      subcmds=(
      "list:List ${words[1]}"
      "show:show ${words[1]}"
      "create:Create a new ${words[1]}"
      "import:Import ${words[1]} resource"
      )
      _describe 'command' subcmds
  elif (( CURRENT == 4 )); then
      case "${words[1]}-${words[2]}-${words[3]}" in
          v5-workspace-create)
            _files ;;
          v5-*-list | v5-*-create | v5-*-import)
            subcmds=($(v5 workspace list | jq -r ".workspaces" | v5-stream | v5-fields id projectName | jq --slurp | jq -r '.[] | "\(.id):\(.projectName)"'))
            _describe 'command' subcmds ;;
      esac
  elif (( CURRENT == 5 )); then
      case "${words[1]}-${words[2]}-${words[3]}" in
          v5-*-list | v5-*-create)
            _files ;;
          v5-*-import)
            subcmds=($(v5 resource list ${words[4]} | jq -r ".resources" | v5-stream | v5-fields id name | jq --slurp | jq -r '.[] | "\(.id):\(.name)"'))
            _describe 'command' subcmds ;;
      esac
  fi

  return 0
}

compdef _v5 v5

function _v5::help () {
    cat <<EOF
Usage: v5 <command> [options]

Available commands:

    init         Manage workspaces
    workspace    Manage workspaces
    contact      Manage contacts
    resource     Manage resources
    message      Manage messages

EOF
}

#####################################################################
# Init
#####################################################################

function _v5::init {
  if [ -n "${WHISPIR_API_USER}" ] && [ -n "${WHISPIR_API_PASS}" ]; then
    echo "============================================="
    echo "WHISPIR_API_TOKEN .... ${WHISPIR_API_TOKEN}"
    echo "WHISPIR_API_USER ..... ${WHISPIR_API_USER}"
    echo "WHISPIR_API_PASS ..... ${WHISPIR_API_PASS}"
    echo "============================================="
  else
    echo "============================================="
    echo "Create a new User and API Token"
    echo "WHISPIR_API_TOKEN=<Token>"
    echo "WHISPIR_API_USER=<User>"
    echo "WHISPIR_API_PASS=<Password>"
    echo "============================================="
  fi
}

#####################################################################
# Debug
#####################################################################

function _v5::debug () {
  export V5_API_DEBUG=$((1-V5_API_DEBUG))
  echo "================================================================"
  echo "Toggle the whispir v5 api curl debug to [${V5_API_DEBUG}]"
  echo "================================================================"
}

#####################################################################
# Workspace
#####################################################################

function _v5::workspace () {
  (( $# > 0 && $+functions[_v5::workspace::$1] )) || {
    cat <<EOF
Usage: v5 workspace <command> [options]

Available commands:

  create [name]
  show   [id]
  list

EOF
    return 1
  }

  local command="$1"
  shift

  _v5::workspace::$command "$@"
}

function _v5::workspace::list () {
  v5-get "workspace" "workspaces"
}

function _v5::workspace::show () {
  v5-get "workspace" "workspaces/${1}"
}

function _v5::workspace::create () {
  local WORKSPACE=${1:-$(</dev/stdin)}
  if [[ -f ${WORKSPACE} ]]; then
    v5-post "workspace" "workspaces" "$(cat ${WORKSPACE})"
  elif [[ -n ${WORKSPACE} ]]; then
    v5-post "workspace" "workspaces" "{                         \
      \"projectName\" : \"${WORKSPACE}\",                        \
      \"billingcostcentre\" : \"$(wsp-random-string)\",          \
      \"status\" : \"A\"                                         \
}"
  else
    v5-post "workspace" "workspaces" "{                         \
      \"projectName\" : \"$(wsp-random-string)\",                \
      \"billingcostcentre\" : \"$(wsp-random-string)\",          \
      \"status\" : \"A\"                                         \
}"
  fi
}

#####################################################################
# Contact
#####################################################################

function _v5::contact () {
  (( $# > 0 && $+functions[_v5::contact::$1] )) || {
    cat <<EOF
Usage: v5 contact <command> [options]

Available commands:

  create [workspace] [name]
  show   [workspace] [id]
  list   [workspace]

EOF
    return 1
  }

  local command="$1"
  shift

  _v5::contact::$command "$@"
}

function _v5::contact::list () {
  if [ $# -eq 1 ]; then
    v5-get "contact" "workspaces/${1}/contacts"
  else
    v5-get "contact" "contacts"
  fi
}

function _v5::contact::show () {
  if [ $# -eq 2 ]; then
    v5-get "contact" "workspaces/${1}/contacts/${2}"
  else
    v5-get "contact" "contacts/${1}"
  fi
}

function _v5::contact::import () {
  local WORKSPACE=${1:-""}
  local RESOURCE=${2:-""}

  if [[ -n ${RESOURCE} ]]; then
    RESOURCE="{                                                   \
    \"resourceId\"     : \"${RESOURCE}\",                         \
    \"importType\"     : \"contact\",                             \
    \"importOptions\": {                                          \
      \"fieldMapping\" : {                                        \
            \"firstName\"         : \"FirstName\",                \
            \"lastName\"          : \"LastName\",                 \
            \"workEmailAddress1\" : \"WorkEmailAddressPrimary\",  \
            \"workMobilePhone1\"  : \"WorkMobilePhonePrimary\",   \
            \"workCountry\"       : \"WorkCountry\",              \
            \"timezone\"          : \"Timezone\",                 \
            \"role\"              : \"Role\"                      \
      },                                                          \
      \"importMode\" : \"replace\"                                \
    }                                                             \
}"
  fi

  if [ -n "${WORKSPACE}" ]
  then
    v5-post "importcontact" "workspaces/${WORKSPACE}/imports" "${RESOURCE}"
  else
    v5-post "importcontact" "imports" "${RESOURCE}"
  fi
}

function _v5::contact::create () {
  local WORKSPACE=${1:-""}
  local CONTACT=${2:-$(</dev/stdin)}

  if [[ -f ${CONTACT} ]]; then
    CONTACT=$(cat ${CONTACT})
  fi

  if [[ -z "${CONTACT}" ]]; then
    CONTACT="{                                                                      \
    \"firstName\"         : \"$(wsp-random-string)\",                               \
    \"lastName\"          : \"$(wsp-random-string)\",                               \
    \"status\"            : \"A\",                                                  \
    \"timezone\"          : \"Australia/Melbourne\",                                \
    \"workEmailAddress1\" : \"$(wsp-random-string)@$(wsp-random-string).com\",      \
    \"workMobilePhone1\"  : \"614$(wsp-random-number)$(wsp-random-number)\",        \
    \"workCountry\"       : \"Australia\",                                          \
    \"locations\" : [{                                                              \
          \"longitude\" : -12.4964,                                                 \
          \"latitude\"  : 41.9028,                                                  \
          \"type\"      : \"CurrentLocation\"                                       \
    }],                                                                             \
    \"messagingoptions\" : [{                                                       \
          \"channel\" : \"sms\",                                                    \
          \"enabled\" : \"true\",                                                   \
          \"primary\" : \"WorkMobilePhone1\"                                        \
        },{                                                                         \
          \"channel\" : \"email\",                                                  \
          \"enabled\" : \"true\",                                                   \
          \"primary\" : \"WorkEmailAddress1\"                                       \
        },{                                                                         \
          \"channel\" : \"voice\",                                                  \
          \"enabled\" : \"true\",                                                   \
          \"primary\" : \"WorkMobilePhone1\"                                        \
    }]                                                                              \
}"
  fi

  if [ -n "${WORKSPACE}" ]
  then
    v5-post "contact" "workspaces/${1}/contacts" "${CONTACT}"
  else
    v5-post "contact" "contacts" "${CONTACT}"
  fi
}

#####################################################################
# Resource
#####################################################################

function _v5::resource () {
  (( $# > 0 && $+functions[_v5::resource::$1] )) || {
    cat <<EOF
Usage: v5 resource <command> [options]

Available commands:

  create [workspace] [name]
  show   [workspace] [id]
  list   [workspace]

EOF
    return 1
  }

  local command="$1"
  shift

  _v5::resource::$command "$@"
}

function _v5::resource::list () {
  if [ $# -eq 1 ]; then
    v5-get "resource" "workspaces/${1}/resources"
  else
    v5-get "resource" "resources"
  fi
}

function _v5::resource::show () {
  if [ $# -eq 2 ]; then
    v5-get "resource" "workspaces/${1}/resources/${2}"
  else
    v5-get "resource" "workspaces/${1}/resources"
  fi
}

function _v5::resource::create () {
  local WORKSPACE=${1:-""}
  local RESOURCE=${2:-$(</dev/stdin)}

  if [[ -f ${RESOURCE} ]]; then
    RESOURCE="{                                           \
    \"name\"     : \"${RESOURCE}\",                       \
    \"scope\"    : \"private\",                           \
    \"mimeType\" : \"text/csv\",                          \
    \"derefUri\" : \"$(cat ${RESOURCE} | base64 -)\"      \
  }"
  fi

  if [ -n "${WORKSPACE}" ]
  then
    v5-post "resource" "workspaces/${1}/resources" "${RESOURCE}"
  else
    v5-post "resource" "resources" "${RESOURCE}"
  fi
}

#####################################################################
# Message
#####################################################################

function _v5::message () {
  (( $# > 0 && $+functions[_v5::message::$1] )) || {
    cat <<EOF
Usage: v5 message <command> [options]

Available commands:

  create [workspace] [name]
  show   [workspace] [id]
  list   [workspace]

EOF
    return 1
  }

  local command="$1"
  shift

  _v5::message::$command "$@"
}

function _v5::message::list () {
  if [ $# -eq 1 ]; then
    v5-get "message" "workspaces/${1}/messages"
  else
    v5-get "message" "messages"
  fi
}

function _v5::message::show () {
  if [ $# -eq 2 ]; then
    v5-get "message" "workspaces/${1}/message/${2}"
  else
    v5-get "message" "workspaces/${1}/message"
  fi
}
