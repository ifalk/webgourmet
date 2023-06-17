### Makefile --- 

## Author: falk@gurumusch
## Version: $Id: Makefile,v 0.0 2020/03/27 09:13:42 falk Exp $
## Keywords: 
## X-URL: 

SCRIPTS_PL=scripts

#RECIPES_DB=/home/falk/webgourmet/tests/recipes.db
#RECIPES_DB=/home/falk/webgourmet/recipes_202306.db
RECIPES_DB=/home/falk/webgourmet/recipes_20230615.db

JS_CSS=/home/falk/webgourmet/web

WWW_LOCAL=/var/www/html/rezepte
WWW=/home/falk/www/rezepte

HTML_LOCAL = html_export


.PHONY: clean_local copy_local clean_www copy_www show_last_db_mod clean_html clean_json

JSON=/home/falk/www/rezepte/recipes.json

### extract data from gourmet db and store it in json hashes - needed later to generate html files
### also extracts images, stores them in html_dir/pics

recipe_hash.json ingredient_hash.json: $(SCRIPTS_PL)/extract_and_store_hashes.pl $(RECIPES_DB)
	$(info Make: *** Extracting data from db, storing in json hashes ***)
	-perl $< --db=$(RECIPES_DB) --recipe_json=recipe_hash.json --ingredient_json=ingredient_hash.json --html_dir=html_export

### export data from json files to html, for all recipes and ingredients
### generates a json file containing information for producing the html index

id2file_name.json: $(SCRIPTS_PL)/export_all_recipes_2_html.pl recipe_hash.json ingredient_hash.json
	$(info Make: *** Exporting all recipes to html ***)
	-perl $< --db=$(RECIPES_DB) --recipe_json=recipe_hash.json --ingredient_json=ingredient_hash.json --html_dir=$(HTML_LOCAL) > $@ && \
	sleep 2


### produce index.html
index.html: $(SCRIPTS_PL)/make_html_index.pl id2file_name.json
	$(info Make: *** Producing index.html ***)
	-perl $< --db=$(RECIPES_DB) --id2file_name_json=id2file_name.json && \
	cp $@ $(HTML_LOCAL)/


### generate json array containing recipes from gourmet sqlite db
## Please ensure that db is not locked when calling
# recipes.json: $(SCRIPTS_PL)/db2json.pl id_2_html_links.pl $(RECIPES_DB)
# 	perl $< --links=./id_2_html_links.pl $(RECIPES_DB) > $@
# recipes.json: $(SCRIPTS_PL)/db2json.pl $(RECIPES_DB)
# 	perl $< $(RECIPES_DB) > $@

### generate json array from hashes extracted and stored from gourmet sqlite db
recipes.json: $(SCRIPTS_PL)/make_json_for_search.pl recipe_hash.json ingredient_hash.json id2file_name.json
	$(info Make: *** Producing recipes.json needed for search ***)
	-perl $< --recipe_json=recipe_hash.json --ingredient_json=ingredient_hash.json --id2file_name_json=id2file_name.json > $@

### we no longer need this (2023-06)
# DB_LAST_MOD := $(shell stat -c %y $$RECIPES_DB | cut -d" " -f1)
# DB_LAST_MOD := $(shell echo $$RECIPES_DB)
# show_last_db_mod: $(RECIPES_DB)
# 	DB_LAST_MOD=$$(stat -c %y $(RECIPES_DB) | cut -d" " -f1) ;\
# 	echo $$DB_LAST_MOD

### copy files to apache root for test
clean_local: 
	cd $(WWW_LOCAL) && \
	sudo rm -f *.htm* && \
	sudo rm -rf pics && \
	sudo rm -f recipes.json && \
	sudo rm -f index.html && \
	sudo rm -f *.css && \
	sudo rm -f *.js

copy_local: clean_local recipes.json index.html
	sudo cp $(HTML_LOCAL)/*.htm* $(WWW_LOCAL)/ && \
	sudo cp -r $(HTML_LOCAL)/pics $(WWW_LOCAL)/ && \
	sudo cp $(HTML_LOCAL)/style.css $(WWW_LOCAL)/ && \
	sudo cp recipes.json $(WWW_LOCAL)/ && \
	sudo cp index.html $(WWW_LOCAL)/ && \
	sudo cp $(JS_CSS)/*.js $(WWW_LOCAL)/ && \
	sudo cp $(JS_CSS)/*.css $(WWW_LOCAL)/

### copy files to www directory - so they can be transfered to server via git
clean_www:
	cd $(WWW) && \
	rm -f *.htm* && \
	rm -rf pics && \
	rm -f recipes.json && \
	rm -f index.html && \
	rm -f *.css && \
	rm -f *.js

copy_www:
	cp $(HTML_LOCAL)/*.htm* $(WWW)/ && \
	cp -r $(HTML_LOCAL)/pics $(WWW)/ && \
	cp $(HTML_LOCAL)/style.css $(WWW)/ && \
	cp recipes.json $(WWW)/ && \
	cp index.html $(WWW)/ && \
	cp $(JS_CSS)/*.js $(WWW)/ && \
	cp $(JS_CSS)/*.css $(WWW)/

### remove local html files (for testing)
clean_html:
	cd $(HTML_LOCAL) && \
	rm -f *.htm* && \
	rm -f index.html && \
	rm -rf pics
clean_json:
	rm -f recipe_hash.json && \
	rm -f ingredient_hash.json && \
	rm -f id2file_name.json

### Makefile ends here
