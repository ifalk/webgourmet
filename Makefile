### Makefile --- 

## Author: falk@gurumusch
## Version: $Id: Makefile,v 0.0 2020/03/27 09:13:42 falk Exp $
## Keywords: 
## X-URL: 

SCRIPTS_PL=scripts

RECIPES_DB=/home/falk/.gourmet/recipes.20200923.db

.PHONY: test_links

### this is only for consistency testing
HTML=/home/falk/gourmet_html/Rezepte.html/index.htm
JSON=/home/falk/www/rezepte/recipes.json
test_links: $(SCRIPTS_PL)/test_links.pl $(HTML) $(JSON)
	perl $< --json=$(JSON) $(HTML)

### generate perl hash db-id -> html file name, using index file produced by gourmet html export
id_2_html_links.pl: $(SCRIPTS_PL)/get_id2html_links.pl $(HTML)
	perl $< $(HTML) > $@

### generate json array containing recipes from gourmet sqlite db
## Please ensure that db is not locked when calling
recipes.json: $(SCRIPTS_PL)/db2json.pl id_2_html_links.pl $(RECIPES_DB)
	perl $< --links=./id_2_html_links.pl $(RECIPES_DB) > $@

### another more elaborate way of accessing the db and building the json array
recipes.json: exportjson.pl id_2_html_links.pl $(RECIPES_DB)
	perl $< --ids2links=./id_2_html_links.pl $(RECIPES_DB) > $@

### generate index.html by combining index file produced by gourmet
### html export and recipes.json generated earlier
index.html: $(SCRIPTS_PL)/make_html_index.pl $(HTML) recipes.json
	perl $< --gourmet_index=$(HTML) --json=recipes.json > $@

### Makefile ends here
