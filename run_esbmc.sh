#!/bin/bash

# Definir intervalos iniciais para temperatura, umidade e pressão
TEMP_LOWER=0
TEMP_UPPER=50
HUMIDITY_LOWER=0
HUMIDITY_UPPER=100
PRESSURE_LOWER=0
PRESSURE_UPPER=9999

# Calcular a amplitude dos intervalos
TEMP_RANGE=$((TEMP_UPPER - TEMP_LOWER))
HUMIDITY_RANGE=$((HUMIDITY_UPPER - HUMIDITY_LOWER))
PRESSURE_RANGE=$((PRESSURE_UPPER - PRESSURE_LOWER))

# Número de partições desejado
PARTITION_NUMBER=1

# Determinar o parâmetro com o maior intervalo
if [ $TEMP_RANGE -ge $HUMIDITY_RANGE ] && [ $TEMP_RANGE -ge $PRESSURE_RANGE ]; then
  PARAM="temperature"
  LOWER_BOUND=$TEMP_LOWER
  UPPER_BOUND=$TEMP_UPPER
elif [ $HUMIDITY_RANGE -ge $TEMP_RANGE ] && [ $HUMIDITY_RANGE -ge $PRESSURE_RANGE ]; then
  PARAM="humidity"
  LOWER_BOUND=$HUMIDITY_LOWER
  UPPER_BOUND=$HUMIDITY_UPPER
else
  PARAM="pressure"
  LOWER_BOUND=$PRESSURE_LOWER
  UPPER_BOUND=$PRESSURE_UPPER
fi

# Função para particionar e executar o ESBMC
partition_and_run() {
  local lower=$1
  local upper=$2
  local param=$3
  local partition_number=$4
  local pids=()
  local failed=0
  
  # Calcular o tamanho de cada partição
  local partition_size=$(( (upper - lower + partition_number - 1) / partition_number ))

  while [ $lower -lt $upper ]; do
    local part_upper=$((lower + partition_size - 1))
    if [ $part_upper -gt $upper ]; then
      part_upper=$upper
    fi
    
    echo "====================================================="
    echo "Running ESBMC with $param in [$lower, $part_upper]"
    echo "-----------------------------------------------------"
    
    if [ "$param" = "temperature" ]; then
      esbmc --k-induction $PROGRAM -DTEMP_LOWER=$lower -DTEMP_UPPER=$part_upper -DHUMIDITY_LOWER=$HUMIDITY_LOWER -DHUMIDITY_UPPER=$HUMIDITY_UPPER -DPRESSURE_LOWER=$PRESSURE_LOWER -DPRESSURE_UPPER=$PRESSURE_UPPER > "result_${PARAM}_${lower}_${part_upper}.txt" 2>&1 &
    elif [ "$param" = "humidity" ]; then
      esbmc --k-induction $PROGRAM -DTEMP_LOWER=$TEMP_LOWER -DTEMP_UPPER=$TEMP_UPPER -DHUMIDITY_LOWER=$lower -DHUMIDITY_UPPER=$part_upper -DPRESSURE_LOWER=$PRESSURE_LOWER -DPRESSURE_UPPER=$PRESSURE_UPPER > "result_${PARAM}_${lower}_${part_upper}.txt" 2>&1 &
    else
      esbmc --k-induction $PROGRAM -DTEMP_LOWER=$TEMP_LOWER -DTEMP_UPPER=$TEMP_UPPER -DHUMIDITY_LOWER=$HUMIDITY_LOWER -DHUMIDITY_UPPER=$HUMIDITY_UPPER -DPRESSURE_LOWER=$lower -DPRESSURE_UPPER=$part_upper > "result_${PARAM}_${lower}_${part_upper}.txt" 2>&1 &
    fi
    
    pids+=($!)
    
    lower=$((part_upper + 1))
  done
  
  # Esperar por todos os processos filhos e verificar falhas
  for pid in "${pids[@]}"; do
    wait $pid || failed=1
    if [ "$failed" = 1 ]; then
      return $failed
    fi
  done

  return $failed
}

# Caminho para o programa
PROGRAM="src/iot_program.cpp"

# Iniciar a contagem de tempo total
start_time=$(date +%s)

# Executar a partição e verificação para o parâmetro com o maior intervalo
partition_and_run $LOWER_BOUND $UPPER_BOUND $PARAM $PARTITION_NUMBER
result=$?

# Exibir resultados de cada partição apenas em caso de falha
any_failures=0
lower=$LOWER_BOUND
partition_size=$(( (UPPER_BOUND - LOWER_BOUND + PARTITION_NUMBER - 1) / PARTITION_NUMBER ))
while [ $lower -lt $UPPER_BOUND ]; do
  part_upper=$((lower + partition_size - 1))
  if [ $part_upper -gt $UPPER_BOUND ]; then
    part_upper=$UPPER_BOUND
  fi
  
  result_file="result_${PARAM}_${lower}_${part_upper}.txt"
  
  if grep -q "VERIFICATION FAILED" "$result_file"; then
    any_failures=1
    echo "====================================================="
    echo "Failure in ESBMC with $param in [$lower, $part_upper]"
    echo "-----------------------------------------------------"
    cat "$result_file"
    echo "-----------------------------------------------------"
  fi
  
  lower=$((part_upper + 1))
done

# Finalizar a contagem de tempo total
end_time=$(date +%s)
elapsed_time=$((end_time - start_time))

# Exibir o resultado final e o tempo decorrido
if [ $any_failures -eq 0 ]; then
  echo "====================================================="
  echo "VERIFICATION SUCCESSFUL"
  echo "Time elapsed: $elapsed_time seconds"
  echo "====================================================="
else
  echo "====================================================="
  echo "VERIFICATION FAILED"
  echo "Time elapsed: $elapsed_time seconds"
  echo "====================================================="
fi

exit $result

