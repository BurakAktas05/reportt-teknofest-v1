import requests
import json
import time

OVERPASS_URL = "http://overpass-api.de/api/interpreter"

# Overpass QL Query: Find all "amenity=police" in "Türkiye"
OVERPASS_QUERY = """
[out:json][timeout:300];
area["name"="Türkiye"]->.searchArea;
nwr["amenity"="police"](area.searchArea);
out center;
"""

def fetch_stations():
    print("OpenStreetMap'ten Türkiye'deki polis karakolları çekiliyor. Lütfen bekleyin...")
    headers = {
        'User-Agent': 'ReporttComplaintApp/1.0 (contact: admin@reportt.com)'
    }
    response = requests.post(OVERPASS_URL, data={'data': OVERPASS_QUERY}, headers=headers)
    response.raise_for_status()
    data = response.json()

    stations = []
    for element in data.get("elements", []):
        tags = element.get("tags", {})
        
        # Get coordinates
        lat = element.get("lat")
        lon = element.get("lon")
        
        # If it's a way/relation, Overpass 'out center' gives center coordinates
        if lat is None or lon is None:
            center = element.get("center")
            if center:
                lat = center.get("lat")
                lon = center.get("lon")
        
        if lat is None or lon is None:
            continue
            
        # Get name and fallback
        name = tags.get("name", tags.get("official_name", "İsimsiz Karakol"))
        
        # Skip generic generic or unnamed ones if you want, but we will keep them as "İsimsiz Karakol"
        
        # Get district (ilçe)
        district = tags.get("addr:district", tags.get("addr:city", tags.get("addr:province", "Bilinmiyor")))
        
        phone = tags.get("phone", tags.get("contact:phone", None))
        
        stations.append({
            "name": name,
            "district": district,
            "lat": lat,
            "lon": lon,
            "phone": phone
        })

    print(f"Toplam {len(stations)} karakol bulundu!")
    return stations

def generate_sql(stations, output_file):
    print(f"SQL dosyası oluşturuluyor: {output_file}")
    with open(output_file, 'w', encoding='utf-8') as f:
        f.write("-- OpenStreetMap üzerinden çekilen gerçek Türkiye Karakol verileri\n")
        f.write("SET search_path TO complaint_app, public;\n\n")
        
        # We can do multi-insert chunks to avoid massive single statements
        chunk_size = 100
        for i in range(0, len(stations), chunk_size):
            chunk = stations[i:i + chunk_size]
            f.write("INSERT INTO police_station (station_name, district, station_point, contact_phone) VALUES\n")
            
            values = []
            for s in chunk:
                name = s["name"].replace("'", "''")
                district = s["district"].replace("'", "''")
                phone_val = f"'{s['phone']}'" if s["phone"] else "NULL"
                lat = s["lat"]
                lon = s["lon"]
                
                # PostGIS geometry: ST_SetSRID(ST_MakePoint(lon, lat), 4326)
                geom = f"ST_SetSRID(ST_MakePoint({lon}, {lat}), 4326)"
                
                values.append(f"    ('{name}', '{district}', {geom}, {phone_val})")
            
            f.write(",\n".join(values) + ";\n\n")
            
    print("İşlem tamamlandı.")

if __name__ == "__main__":
    try:
        stations = fetch_stations()
        # Save output to Spring Boot migration folder
        output_path = "../src/main/resources/db/migration/V4__insert_osm_stations.sql"
        generate_sql(stations, output_path)
    except Exception as e:
        print(f"Hata oluştu: {e}")
