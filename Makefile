# where the data lives
datadir = data

# sub directories for raw lehd wac, census tract geometries, processed wac csv
wacdir = $(datadir)/wac
tractsdir = $(datadir)/census_tracts
processeddir = $(datadir)/processed

# filenames for processed lehd wac data
waclq = wac_lq_2015_2002.csv
wacyearly = wac_yearly_breakdown.csv

# filenames for processed census tract geometry data
tractsshp = tracts_2010_4326.shp
tractsjoined = tracts_2010_4326_wac.shp
tractsjoinedjson = tracts_2010_4326_wac.json

# running `make` will do all of the following
all: \
	process_wac_lq \
	process_wac_yearly \
	tracts_to_topojson

clean:
	rm -rf $(datadir)

clean_processed:
	rm -r $(processeddir)/*

data:
	mkdir -p $(wacdir) $(processeddir) $(tractsdir)

# tells make that these targets are not files and are always out of date
.PHONY: all clean clean_processed

fetch_wac_files: data
	wget -i wac_list.txt -P $(wacdir)

# creates a shapefile in wgs84 of census tracts for the 9 county SF Bay Area
process_tracts: data
	# TODO: replace the monolithic us_tract_2010 file with a CA 2010 tracts file that is curl'd from the interweb
	. ./activate_venv.sh; \
	cp data_archived/census_tracts/nhgis0004_shapefile_tl2010_us_tract_2010.zip .; \
	ogr2ogr \
		-overwrite \
		-skipfailures \
		-sql "select substr(GEOID10, 2) as GEOID, TRACTCE10 from US_tract_2010 where STATEFP10 = '06' AND ALAND10 > 0 AND COUNTYFP10 IN ('001', '013', '041', '055', '075', '081', '085', '095', '097')" \
		-t_srs EPSG:4326 \
		$(tractsdir)/$(tractsshp) \
		/vsizip/nhgis0004_shapefile_tl2010_us_tract_2010.zip/US_tract_2010.shp; \
	rm nhgis0004_shapefile_tl2010_us_tract_2010.zip

# TODO: python script should consume filenames from here rather then be hardcoded in the python script
process_wac_lq: fetch_wac_files process_tracts
	. ./activate_venv.sh; \
	python process_wac_data.py

# TODO: python script should consume filenames from here rather then be hardcoded in the python script
process_wac_yearly: fetch_wac_files
	. ./activate_venv.sh; \
	python calc_yearly_totals.py

# joins the processed wac lq csv to the tracts shp
join_tracts: process_wac_lq
	mapshaper $(tractsdir)/$(tractsshp) -join $(processeddir)/$(waclq) keys=GEOID,trct -o $(tractsdir)/$(tractsjoined)

# converts the joined tracts wac lq data to topojson format for the web
tracts_to_topojson: join_tracts
	mapshaper -i $(tractsdir)/$(tractsshp) -simplify 10% -o $(tractsdir)/$(tractsjoinedjson) format=topojson
