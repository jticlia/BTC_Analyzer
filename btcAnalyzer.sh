#!/bin/bash

#Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"


# Variables globales
unconfirmed_transactions="https://www.blockchain.com/explorer/mempool/btc"
inspect_transaction_url="https://blockstream.info/api/tx/"
inspect_address_url="https://blockstream.info/api/address/"
price_usd_api="https://api.coinbase.com/v2/prices/BTC-USD/spot"

# funciones para manejo de tablas

function printTable(){

    local -r delimiter="${1}"
    local -r data="$(removeEmptyLines "${2}")"

    if [[ "${delimiter}" != '' && "$(isEmptyString "${data}")" = 'false' ]]
    then
        local -r numberOfLines="$(wc -l <<< "${data}")"

        if [[ "${numberOfLines}" -gt '0' ]]
        then
            local table=''
            local i=1

            for ((i = 1; i <= "${numberOfLines}"; i = i + 1))
            do
                local line=''
                line="$(sed "${i}q;d" <<< "${data}")"

                local numberOfColumns='0'
                numberOfColumns="$(awk -F "${delimiter}" '{print NF}' <<< "${line}")"

                if [[ "${i}" -eq '1' ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi

                table="${table}\n"

                local j=1

                for ((j = 1; j <= "${numberOfColumns}"; j = j + 1))
                do
                    table="${table}$(printf '#| %s' "$(cut -d "${delimiter}" -f "${j}" <<< "${line}")")"
                done

                table="${table}#|\n"

                if [[ "${i}" -eq '1' ]] || [[ "${numberOfLines}" -gt '1' && "${i}" -eq "${numberOfLines}" ]]
                then
                    table="${table}$(printf '%s#+' "$(repeatString '#+' "${numberOfColumns}")")"
                fi
            done

            if [[ "$(isEmptyString "${table}")" = 'false' ]]
            then
                echo -e "${table}" | column -s '#' -t | awk '{ sub(/^[[:blank:]]*/, "") } /^\+/{ gsub(" ", "-") } 1'
            fi
        fi
    fi
}

function removeEmptyLines(){

    local -r content="${1}"
    echo -e "${content}" | sed '/^\s*$/d'
}

function repeatString(){

    local -r string="${1}"
    local -r numberToRepeat="${2}"

    if [[ "${string}" != '' && "${numberToRepeat}" =~ ^[1-9][0-9]*$ ]]
    then
        local -r result="$(printf "%${numberToRepeat}s")"
        echo -e "${result// /${string}}"
    fi
}

function isEmptyString(){

    local -r string="${1}"

    if [[ "$(trimString "${string}")" = '' ]]
    then
        echo 'true' && return 0
    fi

    echo 'false' && return 1
}

function trimString(){

    local -r string="${1}"
    sed 's,^[[:blank:]]*,,' <<< "${string}" | sed 's,[[:blank:]]*$,,'
}

# ------------------------- script ---------------------------

trap ctrl_c INT

function ctrl_c ()
{
  echo -e "\n${redColour}[!] Saliendo...\n${endColour}"
  rm ut.t* money* *.tmp amount* 2>/dev/null
  tput cnorm; exit 1
}

function helpPanel(){
  echo -e "\n${redColour}[!] Uso: ./btcAnalyzer.sh${endColour}"
  for i in $(seq 1 80); do echo -ne "${redColour}-"; done; echo -ne "${endColour}"
  echo -e "\n\n\t${grayColour}[-e]${endColour}${yellowColour} Modo exploración${endColour}"
  echo -e "\t\t${purpleColour}unconfirmed_transactions${endColour}${yellowColour}:\t Listar transacciones no confirmadas${endColour}"
  echo -e "\t\t${purpleColour}inspect${endColour}${yellowColour}:\t\t\t Inspeccionar un hash de transacción${endColour}"
  echo -e "\t\t${purpleColour}address${endColour}${yellowColour}:\t\t\t Inspeccionar una transacción de dirección${endColour}"
  echo -e "\n\t${grayColour}[-n]${endColour}${yellowColour} Limitar el número de resultados${endColour}${blueColour} (Ejemplo: -n 10)${endColour}"
  echo -e "\n\t${grayColour}[-i]${endColour}${yellowColour} Proporcionar el identificador de transacción${endColour}${blueColour} (Ejemplo: -i  000000000019d6689c085ae165831e934ff763ae46a2a6c172b3f1b60a8ce26f)${endColour}"
  echo -e "\n\t${grayColour}[-a]${endColour}${yellowColour} Proporcionar una dirección de cuenta${endColour}${blueColour} (Ejemplo: -a 1A1zP1eP5QGefi2DMPTfTL5SLmv7DivfNa)${endColour}"
  echo -e "\n\t${grayColour}[-h]${endColour}${yellowColour} Mostrar panel de ayuda${endColour}"
  
  tput cnorm; exit 1
}

function unconfirmedTransactions(){
  number_output=$1
  echo '' > ut.tmp

  while [ "$(cat ut.tmp | wc -l)" == "1" ]; do
    curl -s "$unconfirmed_transactions" | html2text > ut.tmp
  done

  hashes=$(grep -oP '(?<=/explorer/transactions/btc/)[a-f0-9]{64}' ut.tmp | head -n $number_output)

  echo "Hash_Cantidad_Bitcoin_Tiempo" > ut.table
  for hash in $hashes; do
    fragment=$(grep "$hash" ut.tmp -B 1)
    echo "${hash}_$(echo "$fragment" | grep -o '\$[0-9.]*')_$(echo "$fragment" | head -n 1 | cut -d',' -f2 | cut -c 10-)_$(echo "$fragment" | head -n 1 | grep -oP '\d{1,2}/\d{1,2}/\d{4}, \d{2}:\d{2}:\d{2}')" >> ut.table
  done

  cat ut.table | tr '_' ' ' | awk '{print $2}' | grep -v "Cantidad" | tr -d '$' | sed 's/\..*//g' >> money 

  money=0; cat money | while read -r money_in_line; do
    let money+=$money_in_line
    echo $money > money.tmp
  done

  if [ "$(cat ut.table | wc -l)" != "1" ]; then
    echo -ne "${yellowColour}"
    printTable '_' "$(cat ut.table)"
    echo -ne "${endColour}"

    echo -n "Cantidad total_" > amount.table
    echo "\$$(printf "%'.d\n" $(cat money.tmp))" >> amount.table

    echo -ne "${blueColour}"
    printTable '_' "$(cat amount.table)"
    echo -ne "${endColour}"
    rm ut.t* money* amount* 2>/dev/null
    tput cnorm; exit 0
  fi
  
  rm ut.t* money* amount* 2>/dev/null
  tput cnorm;
}

function inspectTransaction(){
  inspect_transaction_hash=$1
  echo "Entrada Total_Salida Total" > total_in_out.tmp
  while [ "$(cat total_in_out.tmp | wc -l)" == "1" ]; do
    curl -fsS "${inspect_transaction_url}${inspect_transaction_hash}" |
    jq -r '([.vin[].prevout.value] | add) as $in
         | ([.vout[].value] | add) as $out
         | "\($in / 1e8) BTC_\($out / 1e8) BTC"' >> total_in_out.tmp
  done
  echo -ne "${grayColour}"
  printTable '_' "$(cat total_in_out.tmp)"
  echo -ne "${endColour}"

  echo "Hash de Entrada_Valor" > entradas.tmp
  while [ "$(cat entradas.tmp | wc -l)" == "1" ]; do
    curl -fsS "${inspect_transaction_url}${inspect_transaction_hash}" | jq -r '.vin[] | "\(.prevout.scriptpubkey_address)_\(.prevout.value / 1e8) BTC"' >> entradas.tmp
  done
  echo -ne "${greenColour}"
  printTable '_' "$(cat entradas.tmp)"
  echo -ne "${endColour}"

  echo "Hash de Salida_Valor" > salidas.tmp
  while [ "$(cat salidas.tmp | wc -l)" == "1" ]; do
    curl -fsS "${inspect_transaction_url}${inspect_transaction_hash}" | jq -r '.vout[] | "\(.scriptpubkey_address)_\(.value / 1e8) BTC"' >> salidas.tmp
  done
  echo -ne "${redColour}"
  printTable '_' "$(cat salidas.tmp)"
  echo -ne "${endColour}"
  
  rm *.tmp 2>/dev/null
  tput cnorm
  exit 0
}

function inspectAddress(){
  address_hash=$1
  echo "Transacciones realizadas_Cantidad total recibida_Cantidad total enviada_Saldo total" > address.inf.tmp
  curl -fsS "${inspect_address_url}${address_hash}" | jq -r '.chain_stats | "\(.tx_count)_\(.funded_txo_sum / 1e8) BTC_\(.spent_txo_sum / 1e8) BTC_\((.funded_txo_sum - .spent_txo_sum)/1e8) BTC"' >> address.inf.tmp
  price_usd="$(curl -fsS "${price_usd_api}" | jq -r '.data.amount')"
  tail -1 address.inf.tmp | awk -F'_' -v p="${price_usd}" '{print $1, $2*p, $3*p, $4*p}' | sed 's/ /_$ /g' >> address.inf.tmp
  
  echo -ne "${grayColour}"
  printTable '_' "$(cat address.inf.tmp)"
  echo -ne "${endColour}"
  rm *tmp 2>/dev/null
  tput cnorm
  exit 0
}

parameter_counter=0

while getopts "e:n:i:a:h:" arg; do
  case $arg in
    e) exploration_mode=$OPTARG; let parameter_counter+=1;;
    n) number_output=$OPTARG; let parameter_counter+=1;;
    i) inspect_transaction=$OPTARG; let parameter_counter+=1;;
    a) inspect_address=$OPTARG; let parameter_counter+=1;;
    h) helpPanel;;
  esac
done

tput civis

if [ $parameter_counter -eq 0 ]; then
  helpPanel
else
  if [ "$(echo $exploration_mode)" == "unconfirmed_transactions" ]; then
    if [ ! "$number_output" ]; then
      number_output=100
      unconfirmedTransactions $number_output
    else
      unconfirmedTransactions $number_output
    fi
  elif [ "$(echo $exploration_mode)" == "inspect" ]; then
    inspectTransaction $inspect_transaction
  elif [ "$(echo $exploration_mode)" == "address" ]; then
    inspectAddress $inspect_address
  fi
fi

tput cnorm
