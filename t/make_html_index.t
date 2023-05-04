use lib '/home/falk/webgourmet/scripts';
use GourmetExport;
use Data::Dumper;
use Test::More qw( no_plan );

use JSON::XS qw(encode_json decode_json);
use File::Slurp qw(read_file write_file);

my $json = read_file('id2file_name.json', { binmode => ':raw' });
my $id2file_name = decode_json($json);

#### extract last modification date (of db)
use DBI;
use DBD::SQLite::Constants qw/:file_open/;

my $database = 'tests/recipes.db';
my $dbh = Local::Modulino::GourmetExport->get_db_handle($database);

my $last_access = Local::Modulino::GourmetExport->get_last_access($dbh);
print STDERR "Last db access: $last_access\n";

$dbh->disconnect();


###########################################################################

use XML::LibXML '1.70';
use Unicode::Collate;
my $uc = Unicode::Collate->new();

sub by_title {
  $uc->cmp($id2file_name->{$a}->{'title'}, $id2file_name->{$b}->{'title'})
  ||
    $a <=> $b
}

my $dom = XML::LibXML->createDocument( "1.0", "UTF-8" );
my $html = $dom->createElement('html');
$html->setAttribute( 'xmnls', "http://www.w3.org/1999/xhtml" );
$dom->setDocumentElement($html);

my $head = $dom->createElement('head');
my $title = $dom->createElement('title');
my $title_text_string = 'Recipe Index';
my $title_text = $dom->createTextNode($title_text_string);
$title->addChild($title_text);
$head->addChild($title);

my $meta = $dom->createElement('meta');
$meta->setAttribute('http-equiv', 'Content-Type');
$meta->setAttribute('content', 'text/html;charset=utf-8');
$head->addChild($meta);

$meta = $dom->createElement('meta');
$meta->setAttribute('name', 'viewport');
$meta->setAttribute('content', 'initial-scale=1.0, maximum-scale=1.0, width=device-width, user-scalable=no');
$head->addChild($meta);

foreach my $script_src ('fraction-0.3.js', 'code.js') {
  my $script = $dom->createElement('script');
  $script->setAttribute('src', $script_src);
  $script->appendText(' ');
  $head->addChild($script);
}

my $link = $dom->createElement('link');
%atts = (
	 'href' => 'styles.css',
	 'rel' => 'stylesheet',
	 'type' => 'text/css',
	 'media' => 'screen'
  );

while (my ($att, $val) = each %atts) {
  $link->setAttribute($att, $val);
};
$head->addChild($link);

$html->addChild($head);

##### body

my $body = $dom->createElement('body');

my $header_text = "Rezept Liste";
my $add_header = "Export von gourmet db vom $last_access";
$header_text = join(', ', $header_text, $add_header);

my $header = $dom->createElement('header');
$header->appendText($header_text);
$body->addChild($header);

### link zur alphabetischen Liste
my $div = $dom->createElement('div');
$div->setAttribute('style', 'text-align:center;margin-bottom:25px');
my $a = $dom->createElement('a');
$a->setAttribute('href', '#alphabetisch');
$a->appendText('Zur alphabetisch sortierten Liste');
$div->addChild($a);
$body->addChild($div);

### js Zeug für webgourmet Suche
$div = $dom->createElement('div');
$div->setAttribute('id', 'recipelist');

$sdiv = $dom->createElement('div');
$sdiv->setAttribute('style', 'text-align:center;');
my $input = $dom->createElement('input');
%atts = (
  'type' => 'text',
  'id' => 'filter',
  'placeholder' => 'Filter...',
  );
while (my ($key, $val) = each %atts) {
  $input->setAttribute($key, $val);
};
$sdiv->addChild($input);
$div->addChild($sdiv);

my $dl = $dom->createElement('dl');
$dl->setAttribute('class', 'recipelist');
$div->addChild($dl);
$body->addChild($div);


my $table = $dom->createElement('table');
$table->setAttribute('class', 'index');
my $tr = $dom->createElement('tr');
my %table_headers = (
  'title' => 'Titel',
  'category' => 'Kategorie',
  'rating' => 'Bewertung',
  );
foreach my $th_class (qw(title category rating)) {
  my $th = $dom->createElement('th');
  $th->setAttribute('class', $th_class);
  $th->appendText($table_headers{$th_class});
  $tr->addChild($th);
}
$table->addChild($tr);

foreach my $id (sort by_title keys %{ $id2file_name }) {
  my $title = $id;
  if ($id2file_name->{$id}->{'title'}) {
    $title = $id2file_name->{$id}->{'title'};
  } else {
    print STDERR "Id $id: no title\n";
  }
  my $file_name = $id2file_name->{$id}->{'html_file_name'};
  my $rating = $id2file_name->{$id}->{'rating'};

  unless ($id2file_name->{$id}->{'category'}) {
    print STDERR "Id $id: no category\n";
  }
  my $category = $id2file_name->{$id}->{'category'};

  my $tr = $dom->createElement('tr');

  ### title with link to html file
  my $td = $dom->createElement('td');
  $td->setAttribute('class', 'title');
  
  my $a = $dom->createElement('a');
  $a->setAttribute('href', $file_name);
  $a->setAttribute('target', '_blank');
  $a->setAttribute('rel', 'noopener noreferrer');
  $a->appendText($title);

  $td->addChild($a);
  $tr->addChild($td);

  ### category
  $td = $dom->createElement('td');
  $td->setAttribute('class', 'category');
  $td->appendText($category);
  $tr->addChild($td);

  ### rating
  $td = $dom->createElement('td');
  $td->setAttribute('class', 'rating');
  $td->appendText($rating);
  $tr->addChild($td);
  

  $table->addChild($tr);
}

$div = $dom->createElement('div');
$div->setAttribute('class', 'index');
$a = $dom->createElement('a');
$a->setAttribute('id', 'alphabetisch');
$div->addChild($a);
$div->addChild($table);
$body->addChild($div);

$body->addChild($div);


$html->addChild($body);





# use XML::LibXML;


# ############### html header ############################
# my $version = '1.0';
# my $encoding = 'utf-8';
# my $doc = XML::LibXML::Document->new( $version, $encoding );

# my $rootnode = 'html';
# my $public = '-//W3C//DTD XHTML 1.0 Strict//EN';
# my $system = 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd';
# my $dtd = $doc->createInternalSubset( $rootnode, $public, $system);

# my $html = $doc->createElementNS('http://www.w3.org/1999/xhtml', 'html');

# my $head = $doc->createElement('head');

# my $meta = $doc->createElement('meta');
# $meta->setAttribute('http-equiv', 'content-type');
# $meta->setAttribute('content', 'text/html; charset=utf-8');
# $head->appendChild($meta);

# $meta = $doc->createElement('meta');
# $meta->setAttribute('name', 'viewport');
# $meta->setAttribute('content', 'initial-scale=1.0, maximum-scale=1.0, width=device-width, user-scalable=no');
# $head->appendChild($meta);


# foreach my $script_src ('fraction-0.3.js', 'code.js') {
#   my $script = $doc->createElement('script');
#   $script->setAttribute('src', $script_src);
#   $script->appendText(' ');
#   $head->addChild($script);
# }

# my $link = $doc->createElement('link');
# %atts = (
# 	 'href' => 'styles.css',
# 	 'rel' => 'stylesheet',
# 	 'type' => 'text/css',
# 	 'media' => 'screen'
#   );

# while (my ($att, $val) = each %atts) {
#   $link->setAttribute($att, $val);
# };
# $head->addChild($link);

# $html->addChild($head);

# ############### html body ##########################################

# my $body = $doc->createElement('body');

# $html->appendChild($body);

# my $header = $doc->createElement('header');
# $header->appendText("Rezept Liste, Export von gourmet db vom $last_access");
# $body->appendChild($header);

# my $div = $doc->createElement('div');
# $div->setAttribute('style', 'text-align:center;margin-bottom:25px');
# my $a = $doc->createElement('a');
# $a->setAttribute('href', '#alphabetisch');
# $a->appendText('Zur alphabetisch sortierten Liste');
# $div->appendChild($a);
# $body->appendChild($div);

# $html->appendChild($body);


my $file_name = 'html_export/index.html';
$dom->toFile($file_name, 1);
