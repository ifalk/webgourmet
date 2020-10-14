### Makefile --- 

## Author: falk@gurumusch
## Version: $Id: Makefile,v 0.0 2020/03/27 09:13:42 falk Exp $
## Keywords: 
## X-URL: 

SCRIPTS_PL=scripts

RECIPES_DB=/home/falk/.gourmet/recipes.20201014.db

HTML_INDEX=/home/falk/gourmet_html/Rezepte.html/index.htm
HTML=/home/falk/gourmet_html/Rezepte.html/

JS_CSS=/home/falk/webgourmet/web

WWW_LOCAL=/var/www/html/rezepte
WWW=/home/falk/www/rezepte

.PHONY: test_links correct_spelling clean_local copy_local clean_www copy_www show_last_db_mod

### this is only for consistency testing

JSON=/home/falk/www/rezepte/recipes.json
test_links: $(SCRIPTS_PL)/test_links.pl $(HTML) $(JSON)
	perl $< --json=$(JSON) $(HTML)

### replace 'E_rtrag' by 'Ertrag' in *.htm files exported by gourmet
correct_spelling:
	cd $(HTML) && sed -i 's/E_rtrag/Ertrag/g' *.htm


### generate perl hash db-id -> html file name, using index file produced by gourmet html export
id_2_html_links.pl: $(SCRIPTS_PL)/get_id2html_links.pl $(HTML_INDEX)
	perl $< $(HTML_INDEX) > $@

### generate json array containing recipes from gourmet sqlite db
## Please ensure that db is not locked when calling
# recipes.json: $(SCRIPTS_PL)/db2json.pl id_2_html_links.pl $(RECIPES_DB)
# 	perl $< --links=./id_2_html_links.pl $(RECIPES_DB) > $@

### another more elaborate way of accessing the db and building the json array
recipes.json: $(SCRIPTS_PL)/exportjson.pl id_2_html_links.pl $(RECIPES_DB)
	perl $< --ids2links=./id_2_html_links.pl $(RECIPES_DB) > $@


# DB_LAST_MOD := $(shell stat -c %y $$RECIPES_DB | cut -d" " -f1)
DB_LAST_MOD := $(shell echo $$RECIPES_DB)
show_last_db_mod: $(RECIPES_DB)
	DB_LAST_MOD=$$(stat -c %y $(RECIPES_DB) | cut -d" " -f1) ;\
	echo $$DB_LAST_MOD

### generate index.html by combining index file produced by gourmet
### html export and recipes.json generated earlier
index.html: $(SCRIPTS_PL)/make_html_index.pl $(HTML_INDEX) recipes.json $(RECIPES_DB)
	DB_LAST_MOD=$$(stat -c %y $(RECIPES_DB) | cut -d" " -f1) ;\
	echo $$DB_LAST_MOD ;\
	perl $< --gourmet_index=$(HTML_INDEX) --db_last_mod=$$DB_LAST_MOD --json=recipes.json > $@

### copy files to apache root for test
clean_local: 
	cd $(WWW_LOCAL) && \
	sudo rm -f *.htm && \
	sudo rm -rf pics && \
	sudo rm -f recipes.json && \
	sudo rm -f index.html && \
	sudo rm -f *.css && \
	sudo rm -f *.js

copy_local: correct_spelling clean_local recipes.json index.html
	sudo cp $(HTML)/*.htm $(WWW_LOCAL)/ && \
	sudo cp -r $(HTML)/pics $(WWW_LOCAL)/ && \
	sudo cp $(HTML)/style.css $(WWW_LOCAL)/ && \
	sudo cp recipes.json $(WWW_LOCAL)/ && \
	sudo cp index.html $(WWW_LOCAL)/ && \
	sudo cp $(JS_CSS)/*.js $(WWW_LOCAL)/ && \
	sudo cp $(JS_CSS)/*.css $(WWW_LOCAL)/

### copy files to www directory - so they can be transfered to server via git
clean_www:
	cd $(WWW) && \
	rm -f *.htm && \
	rm -rf pics && \
	rm -f recipes.json && \
	rm -f index.html && \
	rm -f *.css && \
	rm -f *.js

copy_www:
	cp $(HTML)/*.htm $(WWW)/ && \
	cp -r $(HTML)/pics $(WWW)/ && \
	cp $(HTML)/style.css $(WWW)/ && \
	cp recipes.json $(WWW)/ && \
	cp index.html $(WWW)/ && \
	cp $(JS_CSS)/*.js $(WWW)/ && \
	cp $(JS_CSS)/*.css $(WWW)/

### Makefile ends here
