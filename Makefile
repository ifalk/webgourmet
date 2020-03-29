### Makefile --- 

## Author: falk@gurumusch
## Version: $Id: Makefile,v 0.0 2020/03/27 09:13:42 falk Exp $
## Keywords: 
## X-URL: 

SCRIPTS_PL=scripts

RECIPES_DB=/home/falk/.gourmet/recipes.db.bak

.PHONY: test_links

### this is only for consistency testing
HTML=/home/falk/gourmet_html/Rezepte.html/index.htm
JSON=/home/falk/www/rezepte/recipes.json
test_links: $(SCRIPTS_PL)/test_links.pl $(HTML) $(JSON)
	perl $< --json=$(JSON) $(HTML)

id_2_html_links.pl: $(SCRIPTS_PL)/get_id2html_links.pl $(HTML)
	perl $< $(HTML) > $@

## Please ensure that db is not locked when calling
recipes.json: $(SCRIPTS_PL)/db2json.pl id_2_html_links.pl $(RECIPES_DB)
	perl $< --links=./id_2_html_links.pl $(RECIPES_DB) > $@

### Makefile ends here
