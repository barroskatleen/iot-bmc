// src/iot_program.cpp
#include <cassert>

// Definições de macros para os limites dos intervalos
#ifndef TEMP_LOWER
#define TEMP_LOWER 0
#endif

#ifndef TEMP_UPPER
#define TEMP_UPPER 50
#endif

#ifndef HUMIDITY_LOWER
#define HUMIDITY_LOWER 0
#endif

#ifndef HUMIDITY_UPPER
#define HUMIDITY_UPPER 100
#endif

#ifndef PRESSURE_LOWER
#define PRESSURE_LOWER 0
#endif

#ifndef PRESSURE_UPPER
#define PRESSURE_UPPER 10000
#endif

int main() {
    int temperature;
    int humidity;
    int pressure;
    int max_interactions = 0;

    // Inicializações ou restrições das variáveis
    temperature = nondet_int();
    humidity = nondet_int();
    pressure = nondet_int();

    // Restrições para particionamento usando os limites definidos
    __VERIFIER_assume(temperature >= TEMP_LOWER && temperature <= TEMP_UPPER);
    __VERIFIER_assume(humidity >= HUMIDITY_LOWER && humidity <= HUMIDITY_UPPER);
    __VERIFIER_assume(pressure >= PRESSURE_LOWER && pressure <= PRESSURE_UPPER);

    // Estabiliza valores acima de 4000, apenas o exato 4000 terá problema
    if (pressure > 4000) {
      pressure = 3999;
    }

    while ((temperature < 20 || temperature > 30 ||
           humidity < 20 || humidity > 40 ||
           pressure < 1899 || pressure > 1999) && max_interactions != 20) {
      if (temperature < 20) {
        temperature += 2;
      } else if (temperature > 30) {
        temperature -= 2;
      }
      if (pressure < 1899) {
        pressure += 100;
      } else if (pressure > 1999) {
        pressure -= 100;
      }
      if (humidity < 20) {
        humidity += 5;
      } else if (humidity > 40) {
        humidity -= 5;
      }
      max_interactions++;
    }
    
    // Propriedade a ser verificada: os parâmetros devem estar dentro dos limites seguros
    assert((temperature >= 20 && temperature <= 30) && 
           (humidity >= 20 && humidity <= 40) && 
           (pressure >= 1899 && pressure <= 1999));

    return 0;
}

