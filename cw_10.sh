#!/bin/bash

# Changelog:
# 01/27/2025: Initial version of the script created for automating spatial database processing tasks.
#
# Author: Alicja Rys
#
# Description: Ten skrypt automatyzuje pobieranie, walidację, przetwarzanie i ładowanie danych do bazy PostgreSQL z zapytaniami przestrzennymi. 

# Parametry
NUMERINDEKSU="4150503"                          
TIMESTAMP=$(date +%m%d%Y)                      
LOG_DIR="PROCESSED"
LOG_FILE="$LOG_DIR/script_${TIMESTAMP}.log" 
DOWNLOAD_URL="https://home.agh.edu.pl/~wsarlej/Customers_Nov2024.zip"
OLD_FILE="Customers_old.csv"
PROCESSED_DIR="PROCESSED"
DB_NAME="cw_10"
DB_USER="postgres"
DB_PASSWORD="********"
DB_HOST="localhost"
EMAIL="lynx.alicja@gmail.com"

# Tworzenie wymaganych katalogów
mkdir -p "$LOG_DIR"
mkdir -p "$PROCESSED_DIR"

# Funkcja logowania
log() {
  local MESSAGE="$1"
  echo "$(date +%Y%m%d%H%M%S) - $MESSAGE" | tee -a "$LOG_FILE"
}

# Funkcja obsługi błędów
handle_error() {
  log "BŁĄD: $1"
  exit 1
}

log "Uruchomiono skrypt."

# Sprawdzenie dostępności narzędzi
command -v wget >/dev/null 2>&1 || handle_error "wget nie jest zainstalowany."
command -v unzip >/dev/null 2>&1 || handle_error "unzip nie jest zainstalowany."
command -v psql >/dev/null 2>&1 || handle_error "psql nie jest zainstalowany."

# 1a. Pobieranie plików
download_files() {
  log "Pobieranie pliku z $DOWNLOAD_URL."
  wget -q "$DOWNLOAD_URL" -O Customers_Nov2024.zip || handle_error "Nie udało się pobrać Customers_Nov2024.zip."
  wget -q "$URL_OLD_FILE" -O "$OLD_FILE" || handle_error "Nie udało się pobrać $OLD_FILE."
}
download_files

# 1b. Rozpakowanie pliku ZIP
log "Rozpakowywanie pliku Customers_Nov2024.zip."
unzip -o Customers_Nov2024.zip || handle_error "Nie udało się rozpakować Customers_Nov2024.zip."

# 1c. Walidacja i czyszczenie danych
log "Walidacja i czyszczenie danych."
awk -F, '
BEGIN {valid_count = 0; invalid_count = 0}
NR == 1 {header = $0; n = split($0, columns); print header > "Customers_Nov2024.valid"}
NR > 1 {
  if ($3 ~ /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/ && NF == n) {
    if (!seen[$0]++) {
      print $0 > "Customers_Nov2024.valid"
      valid_count++
    } else {
      print $0 > "Customers_Nov2024.bad_${TIMESTAMP}"
    }
  } else {
    print $0 > "Customers_Nov2024.bad_${TIMESTAMP}"
    invalid_count++
  }
}
END {
  print "Poprawne wiersze: " valid_count > "/dev/stderr"
  print "Niepoprawne wiersze: " invalid_count > "/dev/stderr"
}
' Customers_Nov2024.csv || handle_error "Walidacja nie powiodła się."

# Porównanie z plikiem OLD
log "Usuwanie duplikatów względem pliku starego."
awk -F, '
NR == FNR {old[$0]; next}
!($0 in old) {print > "Customers_Nov2024.final"}
' "$OLD_FILE" Customers_Nov2024.valid || handle_error "Nie udało się utworzyć pliku finalnego."

# 1d. Tworzenie tabeli w PostgreSQL
log "Tworzenie tabeli CUSTOMERS_${NUMERINDEKSU}."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
DROP TABLE IF EXISTS CUSTOMERS_${NUMERINDEKSU};
CREATE TABLE CUSTOMERS_${NUMERINDEKSU} (
    imie TEXT,
    nazwisko TEXT,
    email TEXT,
    lat NUMERIC,
    lon NUMERIC,
    geoloc GEOGRAPHY(POINT, 4326)
);
" || handle_error "Nie udało się utworzyć tabeli."

# 1e. Ładowanie danych do tabeli
log "Ładowanie danych do tabeli CUSTOMERS_${NUMERINDEKSU}."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
\copy CUSTOMERS_${NUMERINDEKSU}(imie, nazwisko, email, lat, lon) FROM 'Customers_Nov2024.final' WITH CSV HEADER;" || handle_error "Nie udało się załadować danych."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
UPDATE CUSTOMERS_${NUMERINDEKSU} SET geoloc = ST_SetSRID(ST_MakePoint(lon, lat), 4326);" || handle_error "Nie udało się zaktualizować lokalizacji geograficznej."

# 1g. Generowanie raportu
log "Generowanie raportu."
REPORT_FILE="$PROCESSED_DIR/CUSTOMERS_LOAD_${TIMESTAMP}.dat"
{
  echo "Liczba wierszy w pliku pobranym z internetu: $(wc -l < Customers_Nov2024.csv)"
  echo "Liczba poprawnych wierszy (po czyszczeniu): $(wc -l < Customers_Nov2024.final)"
} > "$REPORT_FILE"

# Kwerenda SQL dla klientów w promieniu 50 km
log "Wyszukiwanie najlepszych klientów w promieniu 50 km."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
CREATE TABLE IF NOT EXISTS BEST_CUSTOMERS_${NUMERINDEKSU} AS
SELECT imie, nazwisko
FROM CUSTOMERS_${NUMERINDEKSU}
WHERE ST_Distance(geoloc, ST_SetSRID(ST_MakePoint(-75.67329768604034, 41.39988501005976), 4326)::geography) <= 50000;
" || handle_error "Nie udało się wykonać zapytania SQL."

# Eksport danych do CSV
log "Eksportowanie najlepszych klientów do pliku CSV."
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
\copy BEST_CUSTOMERS_${NUMERINDEKSU} TO '$PROCESSED_DIR/BEST_CUSTOMERS_${NUMERINDEKSU}.csv' WITH CSV HEADER;" || handle_error "Nie udało się wyeksportować danych."

# Kompresja wyników
log "Kompresowanie pliku CSV."
zip "$PROCESSED_DIR/BEST_CUSTOMERS_${NUMERINDEKSU}.zip" "$PROCESSED_DIR/BEST_CUSTOMERS_${NUMERINDEKSU}.csv" || handle_error "Nie udało się skompresować pliku."

# Wysyłanie e-maila (wymaga konfiguracji)
# log "Wysyłanie wiadomości e-mail."
# if [ -f "$REPORT_FILE" ] && [ -f "$PROCESSED_DIR/BEST_CUSTOMERS_${NUMERINDEKSU}.zip" ]; then
#   echo "Raport i plik CSV w załączeniu." | mailx -s "Raport z przetwarzania danych" \
#     -A "$REPORT_FILE" \
#     -A "$PROCESSED_DIR/BEST_CUSTOMERS_${NUMERINDEKSU}.zip" \
#     "$EMAIL" || handle_error "Nie udało się wysłać wiadomości e-mail."
# else
#   handle_error "Brak jednego lub więcej plików załączników."
# fi

log "Skrypt zakończył działanie pomyślnie."

