#!/bin/bash

# lib/gps_utils.sh - Shared GPS coordinate processing functions

# Convert DMS (degrees, minutes, seconds) to decimal
# Usage: dms_to_decimal "37 deg 46' 29.64\" N"
dms_to_decimal() {
    local dms="$1"
    local sign=1
    if [[ "$dms" =~ [SW]$ ]]; then
        sign=-1
    fi
    # Extract numbers
    local deg=$(echo "$dms" | grep -oE '[0-9]+ deg' | grep -oE '[0-9]+')
    local min=$(echo "$dms" | grep -oE "[0-9]+'" | grep -oE '[0-9]+')
    local sec=$(echo "$dms" | grep -oE '[0-9]+\.[0-9]+"' | grep -oE '[0-9]+\.[0-9]+')
    if [ -z "$deg" ]; then deg=0; fi
    if [ -z "$min" ]; then min=0; fi
    if [ -z "$sec" ]; then sec=0; fi
    local decimal=$(echo "scale=8; $deg + $min/60 + $sec/3600" | bc -l)
    echo "scale=8; $decimal * $sign" | bc -l
}

# Convert decimal to DMS
# Usage: decimal_to_dms 37.7749 N
decimal_to_dms() {
    local decimal="$1"
    local ref="$2"
    local abs=$(echo "$decimal" | awk '{print ($1 >= 0) ? $1 : -$1}')
    local deg=$(echo "$abs" | awk '{print int($1)}')
    local min=$(echo "$abs" | awk '{print int(($1-int($1))*60)}')
    local sec=$(echo "$abs" | awk '{print (($1-int($1))*60-int(($1-int($1))*60))*60}')
    printf "%d deg %d' %.4f\" %s\n" "$deg" "$min" "$sec" "$ref"
}

# Calculate distance between two decimal GPS coordinates (Haversine formula)
# Usage: gps_distance lat1 lon1 lat2 lon2
gps_distance() {
    local lat1="$1"
    local lon1="$2"
    local lat2="$3"
    local lon2="$4"
    local pi=3.141592653589793
    local r=6371 # Earth radius in km
    local dlat=$(echo "($lat2-$lat1)*$pi/180" | bc -l)
    local dlon=$(echo "($lon2-$lon1)*$pi/180" | bc -l)
    local a=$(echo "s($dlat/2)*s($dlat/2)+c($lat1*$pi/180)*c($lat2*$pi/180)*s($dlon/2)*s($dlon/2)" | bc -l | sed 's/sin/s/g; s/cos/c/g')
    local c=$(echo "2*a( sqrt($a) / sqrt(1-$a) )" | bc -l | sed 's/atan2/a/g')
    local d=$(echo "$r*$c" | bc -l)
    echo "$d"
}

# Check if a point is within a bounding box
# Usage: gps_in_bbox lat lon min_lat max_lat min_lon max_lon
gps_in_bbox() {
    local lat="$1"
    local lon="$2"
    local min_lat="$3"
    local max_lat="$4"
    local min_lon="$5"
    local max_lon="$6"
    if (( $(echo "$lat >= $min_lat && $lat <= $max_lat && $lon >= $min_lon && $lon <= $max_lon" | bc -l) )); then
        return 0
    else
        return 1
    fi
}

# Extract GPS fields from exiftool output
# Usage: extract_gps_fields "metadata string"
extract_gps_fields() {
    local metadata="$1"
    local lat=$(echo "$metadata" | grep -E '^GPS Latitude[[:space:]]*:' | awk -F: '{print $2}' | xargs)
    local lat_ref=$(echo "$metadata" | grep -E '^GPS Latitude Ref[[:space:]]*:' | awk -F: '{print $2}' | xargs)
    local lon=$(echo "$metadata" | grep -E '^GPS Longitude[[:space:]]*:' | awk -F: '{print $2}' | xargs)
    local lon_ref=$(echo "$metadata" | grep -E '^GPS Longitude Ref[[:space:]]*:' | awk -F: '{print $2}' | xargs)
    echo "$lat|$lat_ref|$lon|$lon_ref"
}

# Validate decimal latitude/longitude
validate_decimal_gps() {
    local lat="$1"
    local lon="$2"
    if (( $(echo "$lat < -90 || $lat > 90" | bc -l) )); then
        return 1
    fi
    if (( $(echo "$lon < -180 || $lon > 180" | bc -l) )); then
        return 1
    fi
    return 0
} 