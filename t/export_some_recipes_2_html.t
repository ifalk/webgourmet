use lib '/home/falk/webgourmet/scripts';
use DB2JSON;
use Data::Dumper;
use Test::More qw( no_plan );

### generate html files for some recipes - given by ids

use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::DB2JSON->get_db_handle($database);

my $test_ids = [
  '1302', # recipe w/ other recipe as ingredient
#  '1301', # refered by 1302
  '1305', # also refers to 1301
  '175',  # refers to 40
  '246', # recipe w/ ingredient subgroups
  '1185', # recipe w/ optional ingredients
  '1877', # recipe w/ image
  '1013', 
 '92',   # recipe w/o image, w/ link, cuisine
  '1485', # recipe w/o image, link, cuisine
  # w/ yield, preptime, cooktime, category, rating, source
  ];

my $add_recipes_needed = Local::Modulino::DB2JSON->get_recipes_involved($dbh, $test_ids);
push (@{ $test_ids }, @{ $add_recipes_needed });
print STDERR "All recipes needed: ", join(', ', @{ $test_ids }), "\n";


my $recipe_hash = Local::Modulino::DB2JSON->fetch_some_recipes($dbh, $test_ids);
# print STDERR Dumper($recipe_hash);

my $ingredient_hash = Local::Modulino::DB2JSON->fetch_some_ingredients($dbh, $test_ids, $recipe_hash);

$recipe_hash = Local::Modulino::DB2JSON->fetch_some_categories($dbh, $test_ids, $recipe_hash);

my $pic_dir = 'tests/pics';
my $id2image_file = Local::Modulino::DB2JSON->fetch_some_images($dbh, $test_ids, $pic_dir);
my $img_nbr = scalar(keys %{ $id2image_file });
print STDERR "Number of saved images: $img_nbr\n";
print STDERR Dumper($id2image_file);

my $max_rid = Local::Modulino::DB2JSON->get_max_id($dbh);
print STDERR "Max recipe id: $max_rid\n";

$dbh->disconnect();

### create html documents for given ids

my $id = $test_ids->[0];
my $title = $recipe_hash->{$id}->{'title'};
print STDERR "id: $id, title: $title\n";

#### Where to save the html file to
my $html_dir = 'tests';
my $file_name = "$html_dir/$title$id.html";
#### picture directory in html file: has to be relative to where the html file is
my $rel_picdir = 'pics';

use XML::LibXML;

##################################
### Setup header of html document
#
# for header we need:
# - title from recipe hash
# - link to stylesheet: style.css

my $version = '1.0';
my $encoding = 'utf-8';
my $doc = XML::LibXML::Document->new( $version, $encoding );

my $rootnode = 'html';
my $public = '-//W3C//DTD XHTML 1.0 Strict//EN';
my $system = 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd';
my $dtd = $doc->createInternalSubset( $rootnode, $public, $system);

my $html = $doc->createElementNS('http://www.w3.org/1999/xhtml', 'html');

my $head = $doc->createElement('head');

my $meta = $doc->createElement('meta');
$meta->setAttribute('http-equiv', 'content-type');
$meta->setAttribute('content', 'text/html; charset=utf-8');
$head->appendChild($meta);

$head->appendTextChild('title', $title);

my $css_link = $doc->createElement('link');
$css_link->setAttribute('rel', 'stylesheet');
$css_link->setAttribute('href', 'style.css');
$css_link->setAttribute('type', 'text/css');
$head->appendChild($css_link);

$html->appendChild($head);

###########################################################
### the html body

my $body = $doc->createElement('body');

$html->appendChild($body);

#############
### recipe header/description

my $r_div = $doc->createElement('div');
$r_div->setAttribute('class', 'recipe');
$r_div->setAttribute('itemscope');
$r_div->setAttribute('itemtype', 'http://schema.org/Recipe');

if ($id2image_file->{"$id"}) {
  my $img = $doc->createElement('img');
  $img->setAttribute('src', "$rel_picdir/$id.jpg");
  $img->setAttribute('itemprop', 'image');
  $r_div->appendChild($img);
}  

my $div = $doc->createElement('div');
$div->setAttribute('class', 'header');

my $p = $doc->createElement('p');
$p->setAttribute('class', 'title');

my $span = $doc->createElement('span');
$span->setAttribute('class', 'label');
$span->appendText('Titel:');
$p->appendChild($span);

$span = $doc->createElement('span');
$span->setAttribute('itemprop', 'name');
$span->appendText($title);
$p->appendChild($span);

$div->appendChild($p);

my %cols2labels = (
  'yields' => 'Ertrag',
  'cooktime' => 'Garzeit',
  'preptime' => 'Zubereitungszeit',
  'category' => 'Kategorie',
  'cuisine' => 'Küche',
  'source' => 'Quelle',
  'last_modified' => 'Letzte Änderung',
  'recipe_id' => 'Rezept Nr.',
  );

my %cols2itemprops = (
  'yields' => 'recipeYield',
  'cooktime' => 'cookTime',
  'preptime' => 'prepTime',
  'category' => 'recipeCategory',
  'cuisine' => 'recipeCuisine',
  );

foreach my $col (qw(yields cooktime preptime category cuisine)) {
  if ($recipe_hash->{$id}->{$col}) {
    my $p = $doc->createElement('p');
    $p->setAttribute('class', $col);
    my $span = $doc->createElement('span');
    $span->setAttribute('class', 'label');
    $span->appendText("$cols2labels{$col}:");
    $p->appendChild($span);
    
    $span = $doc->createElement('span');
    $span->setAttribute('itemprop', $cols2itemprops{$col});
    $span->appendText($recipe_hash->{$id}->{$col});
    $p->appendChild($span);

    $div->appendChild($p);
  }
}

if ($recipe_hash->{$id}->{'source'}) {
  $p = $doc->createElement('p');
  $p->setAttribute('class', 'source');
  $span = $doc->createElement('span');
  $span->setAttribute('class', 'label');
  $span->appendText("$cols2labels{'source'}:");
  $p->appendChild($span);
  $p->appendText(" $recipe_hash->{$id}->{'source'}");

  $div->appendChild($p);
}

if (my $link = $recipe_hash->{$id}->{'link'}) {
  $a = $doc->createElement('a');
  $a->setAttribute('href', $link);
  $a->appendText("Originalseite: $link");

  $div->appendChild($a);
}

if ($recipe_hash->{$id}->{'last_modified'}) {
  $p = $doc->createElement('p');
  $p->setAttribute('class', 'last_modified');
  $span = $doc->createElement('span');
  $span->setAttribute('class', 'label');
  $span->appendText("$cols2labels{'last_modified'}:");
  $p->appendChild($span);
  $p->appendText(" $recipe_hash->{$id}->{'last_modified'}");

  $div->appendChild($p);
}

$p = $doc->createElement('p');
$p->setAttribute('class', 'recipe_id');
$span = $doc->createElement('span');
$span->setAttribute('class', 'label');
$span->appendText("$cols2labels{'recipe_id'}:");
$p->appendChild($span);
$p->appendText(" $id (max $max_rid)");

$div->appendChild($p);


$r_div->appendChild($div);

############# ingredients ###################
if ($ingredient_hash->{$id}) {

  my $ing_div = $doc->createElement('div');
  $ing_div->setAttribute('class', 'ing');

  my $h = $doc->createElement('h3');
  $h->appendText('Zutaten');
  $ing_div->appendChild($h);


  my $ing_ref = $ingredient_hash->{$id};
  # print STDERR Dumper($ing_ref);


  my $ul; 
  if ($ing_ref->{'none'}) {
    $ul = Local::Modulino::DB2JSON->ingredient_subgroup_2_html($ingredient_hash, $id, 'none', $doc);
    delete( $ing_ref->{'none'} );
  } else {
    $ul = $doc->createElement('ul');
    $ul->setAttribute('class', 'ing');
  }

  foreach my $subgroup (keys %{ $ing_ref }) {
    
    my $li = $doc->createElement('li');
    $li->setAttribute('class', 'inggroup');
    $li->appendText("$subgroup:");
    
    my $sub_ul = Local::Modulino::DB2JSON->ingredient_subgroup_2_html($ingredient_hash, $id, $subgroup, $doc);
    $li->appendChild($sub_ul);

    $ul->appendChild($li);
  }
  

  $ing_div->appendChild($ul);

  $r_div->appendChild($ing_div);

  
}

######################################
### instructions

if ($recipe_hash->{$id}->{'instructions'}) {

  my $div = $doc->createElement('div');
  $div->setAttribute('class', 'instructions');

  my $h3 = $doc->createElement('h3');
  $h3->appendText('Anweisungen');
  $div->appendChild($h3);
  
  my $ins_div = $doc->createElement('div');
  $ins_div->setAttribute('itemprop', 'recipeInstructions');

  ## split on linux or windows newline chars in string:
  my @ins_lines = split(/\r?\n/, $recipe_hash->{$id}->{'instructions'});

  foreach my $line (@ins_lines) {
    my $p = $doc->createElement('p');
    $p->appendText($line);
    $ins_div->appendChild($p);
  }
  $div->appendChild($ins_div);

  $r_div->appendChild($div);
}


$body->appendChild($r_div);


####


$html->appendChild($body);

$doc->setDocumentElement($html);


$doc->toFile($file_name, 1);	

#$doc->toFH($fh, 1);

