# 				CustomSkip plugin 
#
#    Copyright (c) 2006 Erland Isaksson (erland_i@hotmail.com)
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

package Plugins::CustomSkip::Plugin;

use strict;

use Slim::Buttons::Home;
use Slim::Utils::Misc;
use Slim::Utils::Strings qw(string);
use File::Spec::Functions qw(:ALL);
use Class::Struct;
use DBI qw(:sql_types);
use FindBin qw($Bin);
use Scalar::Util qw(blessed);
use File::Slurp;
use XML::Simple;
use Data::Dumper;
use HTML::Entities;
use Plugins::CustomSkip::Template::Reader;


my $driver;
my $htmlTemplate = 'plugins/CustomSkip/customskip_list.html';
my $ds = getCurrentDS();
my $filterTypes = undef;
my $mixTypes = undef;
my $filters = ();
my %currentFilter = ();
my $PLUGINVERSION = '1.2.1';

my %filterPlugins = ();
	
sub getDisplayName {
	return 'PLUGIN_CUSTOMSKIP';
}

sub getCustomSkipFilterTypes {
	my @result = ();
	my %zapped = (
		'id' => 'zapped',
		'name' => 'Zapped',
		'description' => 'Skip songs in zapped playlist'
	);
	push @result, \%zapped;
	my %track = (
		'id' => 'track',
		'name' => 'Song',
		'mixtype' => 'track',
		'description' => 'Skip selected song',
		'mixonly' => 1, 
		'parameters' => [
			{
				'id' => 'url',
				'type' => 'text',
				'name' => 'Song to skip'
			}
		]
	);
	push @result, \%track;
	my %artist = (
		'id' => 'artist',
		'name' => 'Artist',
		'mixtype' => 'artist',
		'description' => 'Skip songs by selected artist',
		'parameters' => [
			{
				'id' => 'name',
				'type' => 'sqlsinglelist',
				'name' => 'Artist to skip',
				'data' => 'select id,name,name from contributors order by namesort' 
			}
		]
	);
	push @result, \%artist;
	my %notartist = (
		'id' => 'notartist',
		'name' => 'Not artist',
		'mixtype' => 'artist',
		'description' => 'Skip songs not by selected artist',
		'parameters' => [
			{
				'id' => 'name',
				'type' => 'sqlsinglelist',
				'name' => 'Artist not to skip',
				'data' => 'select id,name,name from contributors order by namesort' 
			}
		]
	);
	push @result, \%notartist;
	my %album = (
		'id' => 'album',
		'name' => 'Album',
		'mixtype' => 'album',
		'description' => 'Skip songs from selected album',
		'parameters' => [
			{
				'id' => 'title',
				'type' => 'sqlsinglelist',
				'name' => 'Album to skip',
				'data' => 'select id,title,title from albums order by titlesort' 
			}
		]
	);
	push @result, \%album;
	my %notalbum = (
		'id' => 'notalbum',
		'name' => 'Not album',
		'mixtype' => 'album',
		'description' => 'Skip songs not from selected album',
		'parameters' => [
			{
				'id' => 'title',
				'type' => 'sqlsinglelist',
				'name' => 'Album not to skip',
				'data' => 'select id,title,title from albums order by titlesort' 
			}
		]
	);
	push @result, \%notalbum;
	my %genre = (
		'id' => 'genre',
		'name' => 'Genre',
		'mixtype' => 'genre',
		'description' => 'Skip songs in selected genre',
		'parameters' => [
			{
				'id' => 'name',
				'type' => 'sqlsinglelist',
				'name' => 'Genre to skip',
				'data' => 'select id,name,name from genres order by namesort' 
			}
		]
	);
	push @result, \%genre;
	my %notgenre = (
		'id' => 'notgenre',
		'name' => 'Not genre',
		'mixtype' => 'genre',
		'description' => 'Skip songs not in selected genre',
		'parameters' => [
			{
				'id' => 'name',
				'type' => 'sqlsinglelist',
				'name' => 'Genre not to skip',
				'data' => 'select id,name,name from genres order by namesort' 
			}
		]
	);
	push @result, \%notgenre;
	my %playlist = (
		'id' => 'playlist',
		'name' => 'Playlist',
		'mixtype' => 'playlist',
		'description' => 'Skip songs in selected playlist',
		'parameters' => [
			{
				'id' => 'name',
				'type' => 'sqlsinglelist',
				'name' => 'Playlist to skip',
				'data' => "select playlist_track.playlist,tracks.title,tracks.title from tracks, playlist_track where tracks.id=playlist_track.playlist and tracks.content_type != 'cpl' group by playlist_track.playlist order by titlesort" 
			}
		]
	);
	push @result, \%playlist;
	my %notplaylist = (
		'id' => 'notplaylist',
		'name' => 'Not playlist',
		'mixtype' => 'playlist',
		'description' => 'Skip songs not in selected playlist',
		'parameters' => [
			{
				'id' => 'name',
				'type' => 'sqlsinglelist',
				'name' => 'Playlist not to skip',
				'data' => "select playlist_track.playlist,tracks.title,tracks.title from tracks, playlist_track where tracks.id=playlist_track.playlist and tracks.content_type != 'cpl' group by playlist_track.playlist order by titlesort" 
			}
		]
	);
	push @result, \%notplaylist;
	my %maxyear = (
		'id' => 'maxyear',
		'name' => 'Less Than Year',
		'mixtype' => 'year',
		'description' => 'Skip songs older or equal to selected year',
		'parameters' => [
			{
				'id' => 'year',
				'type' => 'sqlsinglelist',
				'name' => 'Max year to skip',
				'data' => 'select year,year,year from tracks where year is not null and year!=0 group by year order by year desc' 
			}
		]
	);
	push @result, \%maxyear;
	my %minyear = (
		'id' => 'minyear',
		'name' => 'Greater Than Year',
		'mixtype' => 'year',
		'description' => 'Skip songs newer or equal to selected year',
		'parameters' => [
			{
				'id' => 'year',
				'type' => 'sqlsinglelist',
				'name' => 'Min year to skip',
				'data' => 'select year,year,year from tracks where year is not null and year!=0 group by year order by year desc' 
			}
		]
	);
	push @result, \%minyear;
	my %shortsongs = (
		'id' => 'shortsongs',
		'name' => 'Short songs',
		'description' => 'Skip short songs',
		'parameters' => [
			{
				'id' => 'length',
				'type' => 'singlelist',
				'name' => 'Maximum length to skip',
				'data' => '5=5 seconds,10=10 seconds,15=15 seconds,30=30 seconds,60=1 minute,90=1.5 minute,120=2 minutes',
				'value' => 15
			}
		]
	);
	push @result, \%shortsongs;
	my %longsongs = (
		'id' => 'longsongs',
		'name' => 'Long songs',
		'description' => 'Skip long songs',
		'parameters' => [
			{
				'id' => 'length',
				'type' => 'singlelist',
				'name' => 'Minumum length to skip',
				'data' => '300=5 minutes,600=10 minutes,900=15 minutes,1800=30 minutes,3600=1 hour',
				'value' => 900 
			}
		]
	);
	push @result, \%longsongs;
	return \@result;
}

sub checkCustomSkipFilterType {
	my $client = shift;
	my $filter = shift;
	my $track = shift;

	my $parameters = $filter->{'parameter'};
	if($filter->{'id'} eq 'zapped') {
		my $zappedPlaylistName = Slim::Utils::Strings::string('ZAPPED_SONGS');
		my $url = Slim::Utils::Misc::fileURLFromPath( catfile( Slim::Utils::Prefs::get('playlistdir'), $zappedPlaylistName . '.m3u' ) );
		my $dbh = getCurrentDBH();
		my $sth = $dbh->prepare('select playlist_track.track from tracks,playlist_track where tracks.id=playlist_track.playlist and tracks.url=? and playlist_track.track=?');
		my $result = 0;
		eval {
			$sth->bind_param(1, $url , SQL_VARCHAR);
			$sth->bind_param(2, $track->id , SQL_INTEGER);
			$sth->execute();
			if( $sth->fetch() ) {
				$result = 1;
			}
		};
		if ($@) {
			debugMsg("Error executing SQL: $@\n$DBI::errstr\n");
		}
		$sth->finish();
		if($result) {
			return 1;
		}
	}elsif($filter->{'id'} eq 'artist') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'name') {
				my $names = $parameter->{'value'};
				my $name = $names->[0] if(defined($names) && scalar(@$names)>0);
				
				my $artist = $track->artist();
				if(defined($artist) && $artist->name eq $name) {
					return 1;
				}
			}
		}
	}elsif($filter->{'id'} eq 'notartist') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'name') {
				my $names = $parameter->{'value'};
				my $name = $names->[0] if(defined($names) && scalar(@$names)>0);
				my $artist = $track->artist();
				if(!defined($artist) || $artist->name ne $name) {
					return 1;
				}
			}
		}
	}elsif($filter->{'id'} eq 'album') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'title') {
				my $titles = $parameter->{'value'};
				my $title = $titles->[0] if(defined($titles) && scalar(@$titles)>0);
				my $album = $track->album();
				if(defined($album) && $album->title eq $title) {
					return 1;
				}
			}
		}
	}elsif($filter->{'id'} eq 'notalbum') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'title') {
				my $titles = $parameter->{'value'};
				my $title = $titles->[0] if(defined($titles) && scalar(@$titles)>0);
				my $album = $track->album();
				if(!defined($album) || $album->title ne $title) {
					return 1;
				}
			}
		}
	}elsif($filter->{'id'} eq 'genre') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'name') {
				my $names = $parameter->{'value'};
				my $name = $names->[0] if(defined($names) && scalar(@$names)>0);
				my @genres = $track->genres();
				if(defined(@genres)) {
					for my $genre (@genres) {
						if($genre->name eq $name) {
							return 1;
						}
					}
				}
			}
		}
	}elsif($filter->{'id'} eq 'notgenre') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'name') {
				my $names = $parameter->{'value'};
				my $name = $names->[0] if(defined($names) && scalar(@$names)>0);
				my @genres = $track->genres();
				if(defined(@genres)) {
					my $found = 0;
					for my $genre (@genres) {
						if($genre->name eq $name) {
							$found = 1;
						}
					}
					if(!$found) {
						return 1;
					}
				}
			}
		}
	}elsif($filter->{'id'} eq 'shortsongs') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'length') {
				my $lengths = $parameter->{'value'};
				my $length = $lengths->[0] if(defined($lengths) && scalar(@$lengths)>0);
				
				if($track->durationSeconds<=$length) {
					return 1;
				}
			}
		}
	}elsif($filter->{'id'} eq 'longsongs') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'length') {
				my $lengths = $parameter->{'value'};
				my $length = $lengths->[0] if(defined($lengths) && scalar(@$lengths)>0);
				
				if($track->durationSeconds>=$length) {
					return 1;
				}
			}
		}
	}elsif($filter->{'id'} eq 'maxyear') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'year') {
				my $years = $parameter->{'value'};
				my $year = $years->[0] if(defined($years) && scalar(@$years)>0);
				
				if(defined($track->year) && $track->year!=0 && $track->year<=$year) {
					return 1;
				}
			}
		}
	}elsif($filter->{'id'} eq 'minyear') {
		for my $parameter (@$parameters) {
			if($parameter->{'id'} eq 'year') {
				my $years = $parameter->{'value'};
				my $year = $years->[0] if(defined($years) && scalar(@$years)>0);
				
				if(defined($track->year) && $track->year!=0 && $track->year>=$year) {
					return 1;
				}
			}
		}
	}

	return 0;
}

sub getCustomBrowseMixes {
	my $client = shift;
	return Plugins::CustomSkip::Template::Reader::getTemplates($client,'CustomSkip','Mixes','xml','mix');
}

sub getDynamicPlayListFilters {
	my $client = shift;
	my %myFilter = (
		'name' => 'Custom Skip',
		'url' => 'plugins/CustomSkip/customskip_list.html',
		'defaultenabled' => 1
	);

	my %myFilters = (
		'customskip' => \%myFilter
	);
	return \%myFilters;
}

sub executeDynamicPlayListFilter {
	my $client = shift;
	my $filter = shift;
	my $track = shift;
	
	if(!defined($filter) || $filter->{'name'} eq 'Custom Skip') {
		my $filter = getCurrentFilter($client);
		my $skippercentage = 0;
		my $retrylater = undef;
		if(defined($filter)) {
			removeExpiredFilterItems($filter);
			my $filteritems = $filter->{'filter'};
			for my $filteritem (@$filteritems) {
				next unless $skippercentage<100;
			
				my $id = $filteritem->{'id'};
				my $plugin = $filterPlugins{$id};
				debugMsg("Calling: $plugin with: $track\n");
				no strict 'refs';
				debugMsg("Calling: $plugin :: checkCustomSkipFilterType\n");
				my $match =  eval { &{"${plugin}::checkCustomSkipFilterType"}($client,$filteritem,$track) };
				if ($@) {
					debugMsg("Error filtering tracks with $plugin: $@\n");
				}
				use strict 'refs';
				if($match) {
					my $parameters = $filteritem->{'parameter'};
					for my $p (@$parameters) {
						if($p->{'id'} eq 'customskippercentage') {
							my $values = $p->{'value'};
							if(defined($values) && scalar(@$values)>0) {
								if($values->[0] >= $skippercentage) {
									$skippercentage = $values->[0];
								}
							}
						}
						if($p->{'id'} eq 'customskipretrylater') {
							my $values = $p->{'value'};
							if(defined($values) && scalar(@$values)>0) {
								if(!defined($retrylater)) {
									$retrylater = $values->[0];
								}
							}
						}
					}
				}
			}
		}
		if(!defined($retrylater)) {
			$retrylater = 0;
		}
		if($skippercentage>0) {
			my $rnd = int rand (99);
			if($skippercentage<$rnd) {
				return 1;
			}else {
				if($retrylater) {
					return -1;
				}else {
					return 0;
				}
			}
		}else {
			return 1;
		}
	}
	return 1;
}

# Returns the display text for the currently selected item in the menu
sub getDisplayText {
	my ($client, $item) = @_;

	my $id = undef;
	my $name = '';
	if($item) {
		my $filter = $item->{'filter'};
		my $filteritem = $item->{'filteritem'};
		if(defined($filteritem)) {
			$name = $filteritem->{'displayname'};
		}elsif(defined($filter)) {
			$name = $item->{'filter'}->{'name'};
			my $filter = getCurrentFilter($client);
			if(defined($filter) && $item->{'id'} eq $filter->{'id'}) {
				$name .= " (active)";
			}
		}elsif($item->{'id'} eq 'disable') {
			$name = $client->string( 'PLUGIN_CUSTOMSKIP_DISABLE_FILTER');
		}
	}
	return $name;
}


# Returns the overlay to be display next to items in the menu
sub getOverlay {
	my ($client, $item) = @_;
	my $filter = getCurrentFilter($client);
	my $itemFilter = $item->{'filter'};
	if(defined($itemFilter) && !defined($item->{'filteritem'}) && $item->{'id'} ne 'newitem' && (!defined($filter) || $itemFilter->{'id'} ne $filter->{'id'})) {
		return [Slim::Display::Display::symbol('notesymbol'), Slim::Display::Display::symbol('rightarrow')];
	}else {
		return [undef, Slim::Display::Display::symbol('rightarrow')];
	}
}

sub initFilterTypes {
	debugMsg("Searching for filter types\n");
	
	my %localFilterTypes = ();
	my %localMixTypes = ();
	
	no strict 'refs';
	my @enabledplugins;
	if ($::VERSION ge '6.5') {
		@enabledplugins = Slim::Utils::PluginManager::enabledPlugins();
	}else {
		@enabledplugins = Slim::Buttons::Plugins::enabledPlugins();
	}
	for my $plugin (@enabledplugins) {
		if(UNIVERSAL::can("Plugins::$plugin","getCustomSkipFilterTypes") && UNIVERSAL::can("Plugins::$plugin","checkCustomSkipFilterType")) {
			debugMsg("Getting filter types for: $plugin\n");
			my $items = eval { &{"Plugins::${plugin}::getCustomSkipFilterTypes"}() };
			if ($@) {
				debugMsg("Error getting filter types from $plugin: $@\n");
			}
			for my $item (@$items) {
				my $id = $item->{'id'};
				if(defined($id)) {
					$filterPlugins{$id} = "Plugins::${plugin}";
					my $filter = $item;
					debugMsg("Got filter types: ".$filter->{'name'}."\n");
					my @allparameters = ();
					if(defined($filter->{'parameters'})) {
						my $parameters = $filter->{'parameters'};
						@allparameters = @$parameters;
					}
					my %percentageParameter = (
						'id' => 'customskippercentage',
						'type' => 'singlelist',
						'name' => 'Skip percentage',
						'data' => '100=100%,75=75%,50=50%,25=25%,0=0% (remove)',
						'value' => 100
					);
					push @allparameters, \%percentageParameter;
					my %validParameter = (
						'id' => 'customskipvalidtime',
						'type' => 'timelist',
						'name' => 'Valid',
						'data' => '900=15 minutes,1800=30 minutes,3600=1 hour,10800=3 hours,21600=6 hours,86400=24 hours,604800=1 week,1209600=2 weeks,2419200=4 weeks,7776000=3 months,15552000=6 months,0=Forever',
						'value' => 0
					);
					push @allparameters, \%validParameter;
					my %retryLaterParameter = (
						'id' => 'customskipretrylater',
						'type' => 'singlelist',
						'name' => 'Retry later',
						'data' => '0=No,1=Yes',
						'value' => 0
					);
					push @allparameters, \%retryLaterParameter;
					$filter->{'customskipparameters'} = \@allparameters;
					$filter->{'customskipid'} = $id;
					$filter->{'customskipplugin'} = $plugin;
					if(defined($filter->{'mixtype'})) {
						$localMixTypes{$filter->{'mixtype'}} = 1;
					}
					$localFilterTypes{$id} = $filter;
				}
			}
		}
	}
	use strict 'refs';

	$filterTypes = \%localFilterTypes;
	$mixTypes = \%localMixTypes;
}


sub setMode {
	my $client = shift;
	my $method = shift;
	
	if ($method eq 'pop') {
		Slim::Buttons::Common::popMode($client);
		return;
	}

	my @listRef = ();
	initFilters();
	my $localfilters = getFilters($client);
	for my $filter (@$localfilters) {
		my %item = (
			'id' => $filter->{'id'},
			'value' => $filter->{'id'},
			'filter' => $filter
		);
		push @listRef, \%item;
	}
	my %item = (
		'id' => 'disable',
		'value' => 'disable'
	);
	push @listRef, \%item;

	# use INPUT.Choice to display the list of feeds
	my %params = (
		header     => '{PLUGIN_CUSTOMSKIP} {count}',
		listRef    => \@listRef,
		name       => \&getDisplayText,
		overlayRef => \&getOverlay,
		modeName   => 'PLUGIN.CustomSkip',
		parentMode => 'PLUGIN.CustomSkip',
		onPlay     => sub {
			my ($client, $item) = @_;
			my $key = undef;
			if(defined($client)) {
				$key = $client;
				if(defined($client->syncgroupid)) {
					$key = "SyncGroup".$client->syncgroupid;
				}
			}
			if(defined($item->{'filter'}) && defined($key)) {
				$currentFilter{$key} = $item->{'id'};
				$client->prefSet('plugin_customskip_filter',$item->{'id'});
				$client->showBriefly(
					$client->string( 'PLUGIN_CUSTOMSKIP'),
					$client->string( 'PLUGIN_CUSTOMSKIP_ACTIVATING_FILTER').": ".$item->{'filter'}->{'name'},
					1);
				
			}elsif($item->{'id'} eq 'disable' && defined($key)) {
				$currentFilter{$key} = undef;
				$client->prefSet('plugin_customskip_filter',0);
				$client->showBriefly(
					$client->string( 'PLUGIN_CUSTOMSKIP'),
					$client->string( 'PLUGIN_CUSTOMSKIP_DISABLING_FILTER'),
					1);
			}
		},
		onAdd      => sub {
			my ($client, $item) = @_;
			debugMsg("Do nothing on add\n");
		},
		onRight    => sub {
			my ($client, $item) = @_;
			if(defined($item->{'filter'})) {
				my $filter = $filters->{$item->{'id'}};
				my $params = getFilterItemsMenu($client, $filter);
				if(defined($params)) {
					Slim::Buttons::Common::pushModeLeft($client,'INPUT.Choice',$params);
				}else {
					$client->bumpRight();
				}
			}elsif($item->{'id'} eq 'disable') {
				if(defined($client)) {
					my $key = $client;
					if(defined($client->syncgroupid)) {
						$key = "SyncGroup".$client->syncgroupid;
					}
					$currentFilter{$key} = undef;
					$client->prefSet('plugin_customskip_filter',0);
					$client->showBriefly(
						$client->string( 'PLUGIN_CUSTOMSKIP'),
						$client->string( 'PLUGIN_CUSTOMSKIP_DISABLING_FILTER'),
						1);
				}
			}else {
				$client->bumpRight();
			}
		},
	);
	Slim::Buttons::Common::pushMode($client, 'INPUT.Choice', \%params);
}

sub setModeMix {
	my $client = shift;
	my $method = shift;
	
	if ($method eq 'pop') {
		Slim::Buttons::Common::popMode($client);
		return;
	}
	my $selectedFilterType = $client->param('filtertype');
	my $item = $client->param('item');

	initFilterTypes();
	initFilters();
	my @listRef = ();
	for my $key (keys %$filterTypes) {
		my $filterType = $filterTypes->{$key};
		if((!defined($selectedFilterType) && !$filterType->{'mixonly'})|| (defined($filterType->{'mixtype'}) && $filterType->{'mixtype'} eq $selectedFilterType)) {
			my %item = (
				'id' => $filterType->{'id'},
				'value' => $filterType->{'id'},
				'name' => $filterType->{'name'},
				'filtertype' => $filterType
			);
			push @listRef, \%item;
		}
	}
	@listRef = sort { $a->{'name'} cmp $b->{'name'} } @listRef;

	# use INPUT.Choice to display the list of feeds
	my %params = (
		header     => '{PLUGIN_CUSTOMSKIP_SELECT_FILTER_TYPE} {count}',
		listRef    => \@listRef,
		name       => \&getDisplayText,
		overlayRef => \&getOverlay,
		modeName   => 'PLUGIN.CustomSkipMix',
		parentMode => 'PLUGIN.CustomSkipMix',
		onPlay     => sub {
			my ($client, $item) = @_;
			debugMsg("Do nothing on play\n");
		},
		onAdd      => sub {
			my ($client, $item) = @_;
			debugMsg("Do nothing on add\n");
		},
		onRight    => sub {
			my ($client, $item) = @_;
			if(defined($item->{'filtertype'})) {
				my $filterType = $item->{'filtertype'};
				if(defined($filterType->{'customskipparameters'})) {
					my %parameterValues = ();
					my $i=1;
					while(defined($client->param('customskip_parameter_'.$i))) {
						$parameterValues{'customskip_parameter_'.$i} = $client->param('customskip_parameter_'.$i);
						$i++;
					}
					if(defined($client->param('extrapopmode'))) {
						$parameterValues{'extrapopmode'} = $client->param('extrapopmode');
					}
					if(defined($client->param('filter'))) {
						$parameterValues{'filter'} = $client->param('filter');
					}

					my $filter = undef;
					if(defined($client->param('filter'))) {
						$filter = $filters->{$client->param('filter')};
					}else {
						$filter = getCurrentFilter($client);
					}
					my $filteritems = $filter->{'filter'};
					my $i = 1;
					for my $filteritem (@$filteritems) {
						if($filteritem->{'id'} eq $item->{'id'} && defined($client->param('customskip_parameter_1'))) {
							my $parameters = $filterType->{'parameters'};
							my $itemParameters = $filteritem->{'parameter'};
							if(defined($parameters) && scalar(@$parameters)>0 && defined($itemParameters) && scalar(@$itemParameters)>0) {
								my $parameter = $parameters->[0];
								my $itemParameter = $itemParameters->[0];
								my $itemValues = $itemParameter->{'value'};
								if(defined($itemValues) && scalar(@$itemValues)==1) {
									my $itemValue = $itemValues->[0];
									my %currentValues = (
										$client->param('customskip_parameter_1') => $client->param('customskip_parameter_1')
									);
									addValuesToFilterParameter($parameter,\%currentValues);
									my $values = $parameter->{'values'};
									if(defined($values)) {
										for my $item (@$values) {
											if($itemValue eq $item->{'value'}) {
												if($item->{'id'} eq $client->param('customskip_parameter_1')) {
													$parameterValues{'filteritem'} = $i;
												}
												last;
											}
										}
									}else {
										my $value = $parameter->{'value'};
										if($value eq $client->param('customskip_parameter_1')) {
											$parameterValues{'filteritem'} = $i;
										}
									}
								}
							}
						}
						$i = $i + 1;
					}

					requestFirstParameter($client,$filterType,\%parameterValues);
				}else {
					my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
					
					my $filter = undef;
					if(defined($client->param('filter'))) {
						$filter = $filters->{$client->param('filter')};
					}else {
						$filter = getCurrentFilter($client);
					}
					if (defined $browseDir && -d $browseDir && defined($filter)) {
						my $file = unescape($filter->{'id'});
						my $url = catfile($browseDir, $file);
			
						saveFilterItem($client,$url,$filter,$filterType);
					}
				}
			}
		},
	);
	my $i = 1;
	while(defined($client->param('customskip_parameter_'.$i))) {
		$params{'customskip_parameter_'.$i} = $client->param('customskip_parameter_'.$i);
		$i++;
	}
	if(defined($client->param('extrapopmode'))) {
		$params{'extrapopmode'} = $client->param('extrapopmode');
	}
	if(defined($client->param('filter'))) {
		$params{'filter'} = $client->param('filter');
	}
	Slim::Buttons::Common::pushMode($client, 'INPUT.Choice', \%params);
}

sub setModeChooseParameters {
	my $client = shift;
	my $method = shift;
	
	if ($method eq 'pop') {
		Slim::Buttons::Common::popMode($client);
		return;
	}

	my $parameterId = $client->param('customskip_nextparameter');
	my $filterType = $client->param('filtertype');
	my $parameter= $filterType->{'customskipparameters'}->[$parameterId-1];

	my @listRef = ();
	my $currentValues = undef;
	if($client->param('filteritem')) {
		my $filter = undef;
		if(defined($client->param('filter'))) {
			$filter = $filters->{$client->param('filter')};
		}else {
			$filter = getCurrentFilter($client);
		}
		my $filteritem = $filter->{'filter'}->[$client->param('filteritem')-1];
		my $parameters = $filteritem->{'parameter'};
		for my $p (@$parameters) {
			if($p->{'id'} eq $parameter->{'id'}) {
				my $values = $p->{'value'};
				for my $value (@$values) {
					if(!defined($currentValues)) {
						my %valuesHash = ();
						$currentValues = \%valuesHash;
					}
					$currentValues->{$value} = $value;
				}
			}
		}
	}
	addValuesToFilterParameter($parameter,$currentValues);
	my $values = $parameter->{'values'};
	if(defined($values)) {
		@listRef = @$values;
	}else {
		my %item = (
			'id' => $parameter->{'value'},
			'name' => $parameter->{'value'}
		);
		push @listRef,\%item;
	}

	my $name = $parameter->{'name'};
	my %params = (
		header     => "$name {count}",
		listRef    => \@listRef,
		name       => \&getDisplayText,
		overlayRef => \&getOverlay,
		parentName   => 'PLUGIN.CustomSkip.ChooseParameters',
		onRight    => sub {
			my ($client, $item) = @_;
			requestNextParameter($client,$item,$parameterId,$filterType);
		},
		onPlay    => sub {
			my ($client, $item) = @_;
			requestNextParameter($client,$item,$parameterId,$filterType);
		},
		onAdd    => sub {
			my ($client, $item) = @_;
			requestNextParameter($client,$item,$parameterId,$filterType);
		},
		customskip_nextparameter => $parameterId,
		filtertype => $filterType,
	);
	my $i = 0;
	for my $value (@$values) {
		if($value->{'selected'}) {
			$params{'listIndex'} = $i;
		}
		$i = $i + 1;
	}
	$i=1;
	while(defined($client->param('customskip_parameter_'.$i))) {
		$params{'customskip_parameter_'.$i} = $client->param('customskip_parameter_'.$i);
		$i++;
	}
	if(defined($client->param('extrapopmode'))) {
		$params{'extrapopmode'} = $client->param('extrapopmode');
	}
	if(defined($client->param('filter'))) {
		$params{'filter'} = $client->param('filter');
	}
	if(defined($client->param('customskip_startparameter'))) {
		$params{'customskip_startparameter'} = $client->param('customskip_startparameter');
	}
	if(defined($client->param('filteritem'))) {
		$params{'filteritem'} = $client->param('filteritem');
	}

	Slim::Buttons::Common::pushMode($client, 'INPUT.Choice', \%params);
}

sub requestNextParameter {
	my $client = shift;
	my $item = shift;
	my $parameterId = shift;
	my $filterType = shift;

	$client->param('customskip_parameter_'.$parameterId,$item->{'id'});
	my $parameters = $filterType->{'customskipparameters'};
	if(scalar(@$parameters)>$parameterId) {
		my %nextParameter = (
			'customskip_nextparameter' => $parameterId+1,
			'filtertype' => $filterType
		);
		my $i=1;
		while(defined($client->param('customskip_parameter_'.$i))) {
			$nextParameter{'customskip_parameter_'.$i} = $client->param('customskip_parameter_'.$i);
			$i++;
		}
		if(defined($client->param('customskip_startparameter'))) {
			$nextParameter{'customskip_startparameter'} = $client->param('customskip_startparameter');
		}
		if(defined($client->param('filteritem'))) {
			$nextParameter{'filteritem'} = $client->param('filteritem');
		}
		if(defined($client->param('extrapopmode'))) {
			$nextParameter{'extrapopmode'} = $client->param('extrapopmode');
		}
		if(defined($client->param('filter'))) {
			$nextParameter{'filter'} = $client->param('filter');
		}
		Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkip.ChooseParameters',\%nextParameter);
	}else {
		my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
		
		my $filter = undef;
		if(defined($client->param('filter'))) {
			$filter = $filters->{$client->param('filter')};
		}else {
			$filter = getCurrentFilter($client);
		}
		my $success = 0;
		if (defined $browseDir && -d $browseDir && defined($filter)) {
			my $file = unescape($filter->{'id'});
			my $url = catfile($browseDir, $file);

			$success = saveFilterItem($client,$url,$filter,$filterType);
		}else {
			debugMsg("No filter activated, not saving\n");
		}
		my $startParameter = $client->param('customskip_startparameter');
		if(!defined($startParameter)) {
			$startParameter = 1;
		}
		if(defined($client->param('extrapopmode'))) {
			my $extramode = $client->param('extrapopmode');
			for(my $i=0;$i<$extramode;$i++) {
				Slim::Buttons::Common::popMode($client);
			}
		}
		for(my $i=$startParameter;$i<=$parameterId;$i++) {
			Slim::Buttons::Common::popMode($client);
		}
		Slim::Buttons::Common::popMode($client);
		$client->update();
		if($success) {
			$client->showBriefly(
				$client->string( 'PLUGIN_CUSTOMSKIP'),
				$client->string( 'PLUGIN_CUSTOMSKIP_MIX_FILTER_SUCCESS').": ".$filter->{'name'},
				1);
		}else {
			$client->showBriefly(
				$client->string( 'PLUGIN_CUSTOMSKIP'),
				$client->string( 'PLUGIN_CUSTOMSKIP_MIX_FILTER_FAILURE'),
				1);
		}

	}
}


sub requestFirstParameter {
	my $client = shift;
	my $filterType = shift;
	my $params = shift;

	my %nextParameters = (
		'filtertype' => $filterType
	);
	foreach my $pk (keys %$params) {
		$nextParameters{$pk} = $params->{$pk};
	}
	if(defined($params->{'customskip_startparameter'})) {
		$nextParameters{'customskip_startparameter'} = $params->{'customskip_startparameter'};
	}else {
		my $i = 1;
		while(defined($nextParameters{'customskip_parameter_'.$i})) {
			$i++;
		}
		$nextParameters{'customskip_startparameter'}=$i;
	}
	$nextParameters{'customskip_nextparameter'}=$nextParameters{'customskip_startparameter'};

	my $parameters = $filterType->{'customskipparameters'};
	if(defined($parameters) && scalar(@$parameters)>=$nextParameters{'customskip_nextparameter'}) {
		Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkip.ChooseParameters',\%nextParameters);
	}else {
		my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
		
		my $filter = undef;
		if(defined($client->param('filter'))) {
			$filter = $filters->{$client->param('filter')};
		}else {
			$filter = getCurrentFilter($client);
		}
		my $success = 0;
		if (defined $browseDir && -d $browseDir && defined($filter)) {
			my $file = unescape($filter->{'id'});
			my $url = catfile($browseDir, $file);

			$success = saveFilterItem($client,$url,$filter,$filterType);
		}else {
			debugMsg("No filter activated, not saving\n");
		}

		Slim::Buttons::Common::popMode($client);
		if(defined($nextParameters{'extrapopmode'})) {
			for(my $i=0;$i<$nextParameters{'extrapopmode'};$i++) {
				Slim::Buttons::Common::popMode($client);
			}
		}
		$client->update();
		if($success) {
			$client->showBriefly(
				$client->string( 'PLUGIN_CUSTOMSKIP'),
				$client->string( 'PLUGIN_CUSTOMSKIP_MIX_FILTER_SUCCESS').": ".$filter->{'name'},
				1);
		}else {
			$client->showBriefly(
				$client->string( 'PLUGIN_CUSTOMSKIP'),
				$client->string( 'PLUGIN_CUSTOMSKIP_MIX_FILTER_FAILURE'),
				1);
		}

	}
}

sub saveFilterItem {
	my ($client, $url, $filter, $filterType) = @_;
	my $fh;

	my %filterParameters = ();
	my $data = "";
	my @parametersToSave = ();
	my $skippercentage=0;
	if(defined($filterType->{'customskipparameters'})) {
		my $parameters = $filterType->{'customskipparameters'};
		my $i = 1;
		for my $p (@$parameters) {
			if(defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
				my %itemValue = (
					$client->param('customskip_parameter_'.$i) => $client->param('customskip_parameter_'.$i)
				);
				addValuesToFilterParameter($p,\%itemValue);
				my $values = getValueOfFilterParameter($client,$p,$i,"&<>\'\"");
				if(scalar(@$values)>0) {
					my $j = 0;
					for my $value (@$values) {
						$values->[$j] = decode_entities($value);
					}
					my %savedParameter = (
						'id' => $p->{'id'},
						'value' => $values
					);
					if($p->{'id'} eq 'customskippercentage') {
						$skippercentage=$values->[0];
					}
					push @parametersToSave, \%savedParameter;
				}
			}
			$i = $i+1;
		}
	}
	my $filterItems = $filter->{'filter'};
	my %newFilterItem = (
		'id' => $filterType->{'id'},
		'parameter' => \@parametersToSave
	);
	if(defined($client->param('filteritem'))) {
		if($skippercentage) {
			splice(@$filterItems,$client->param('filteritem')-1,1,\%newFilterItem);
		}else {
			splice(@$filterItems,$client->param('filteritem')-1,1);
		}
	}elsif($skippercentage) {
		push @$filterItems,\%newFilterItem;
	}
	$filter->{'filter'} = $filterItems;
	my $error = saveFilter($url,$filter);
	if(!defined($error)) {
		return 1;
	}
	return undef;
}

sub getFilterItemsMenu {
	my $client = shift;
	my $filter = shift;

	my @listRef = ();
	my $itemNo = 1;
	my $filteritems = $filter->{'filter'};
	for my $filteritem (@$filteritems) {
		my %item = (
			'id' => $itemNo,
			'value' => $itemNo,
			'filter' => $filter,
			'filteritem' => $filteritem
		);
		push @listRef, \%item;
		$itemNo = $itemNo + 1;
	}
	my %item= (
		'id' => 'newitem',
		'value' => 'newitem',
		'name' => "Add new filter item",
		'filter' => $filter
	);
	push @listRef, \%item;

	# use INPUT.Choice to display the list of feeds
	my %params = (
		header     => $filter->{'name'}.' {count}',
		listRef    => \@listRef,
		name       => \&getDisplayText,
		overlayRef => \&getOverlay,
		modeName   => 'PLUGIN.CustomSkip.'.$filter->{'id'},
		parentMode => 'PLUGIN.CustomSkip',
		onPlay     => sub {
			my ($client, $item) = @_;
			debugMsg("Do nothing on play\n");
		},
		onAdd      => sub {
			my ($client, $item) = @_;
			debugMsg("Do nothing on add\n");
		},
		onRight    => sub {
			my ($client, $item) = @_;
			if($item->{'id'} eq 'newitem') {
				my %p = (
					'filter' => $item->{'filter'}->{'id'},
					'extrapopmode' => 1
				);
				Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
			}else {
				my %p = (
					'filter' => $item->{'filter'}->{'id'},
					'filteritem' => $item->{'id'}
				);
				my $filterType = $filterTypes->{$item->{'filteritem'}->{'id'}};
				requestFirstParameter($client,$filterType,\%p);
			}
		},
	);
	return \%params;
}

sub trackMix {
	my $client = shift;
	my $item = shift;
	my $addOnly = shift;
	my $web = shift;

	if(!$mixTypes) {
		initFilterTypes();
	}

	if(ref($item) eq 'Slim::Schema::Track') {

		my @listRef = ();
		my $itemobj = objectForId('track',$item->id);
		if($mixTypes->{'track'}) {
			my %item = (
				'id' => 'Song '.$itemobj->id,
				'value' => 'Song '.$itemobj->id,
				'name' => 'Song: '.$itemobj->title,
				'item' => $itemobj
			);
			push @listRef,\%item;
		}
		if($mixTypes->{'album'}) {
			my $album = $itemobj->album();
			if(defined($album)) {
				my %item = (
					'id' => 'Album '.$album->id,
					'value' => 'Album '.$album->id,
					'name' => 'Album: '.$album->title,
					'item' => $album
				);
				push @listRef,\%item;
			}
		}
		if($mixTypes->{'artist'}) {
			my @artists = $itemobj->contributors();
			for my $artist (@artists) {
				my %item = (
					'id' => 'Artist '.$artist->id,
					'value' => 'Artist '.$artist->id,
					'name' => 'Artist: '.$artist->name,
					'item' => $artist
				);
				push @listRef,\%item;
			}
		}
		if($mixTypes->{'genre'}) {
			my @genres = $itemobj->genres();
			for my $genre (@genres) {
				my %item = (
					'id' => 'Genre '.$genre->id,
					'value' => 'Genre '.$genre->id,
					'name' => 'Genre: '.$genre->name,
					'item' => $genre
				);
				push @listRef,\%item;
			}
		}
		@listRef = sort { $a->{'name'} cmp $b->{'name'} } @listRef;
			# use INPUT.Choice to display the list of feeds
		my %params = (
			header     => '{PLUGIN_CUSTOMSKIP_SELECT_MIX_ITEM} {count}',
			listRef    => \@listRef,
			name       => \&getDisplayText,
			overlayRef => \&getOverlay,
			parentMode => 'PLUGIN.CustomSkipMix',
			onPlay     => sub {
				my ($client, $item) = @_;
				debugMsg("Do nothing on play\n");
			},
			onAdd      => sub {
				my ($client, $item) = @_;
				debugMsg("Do nothing on add\n");
			},
			onRight    => sub {
				my ($client, $item) = @_;
				debugMsg("Do something on right for ".$item->{'item'}."\n");
				my $blessed = blessed($item->{'item'});
					if($blessed eq 'Slim::Schema::Track') {
					my %p = (
						'filtertype' => 'track',
						'customskip_parameter_1' => $item->{'item'}->url,
						'extrapopmode' => 1
					);
					Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
					$client->update();
					}elsif($blessed eq 'Slim::Schema::Album') {
					my %p = (
						'filtertype' => 'album',
						'customskip_parameter_1' => $item->{'item'}->id,
						'extrapopmode' => 1
					);
					Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
					$client->update();
					}elsif($blessed eq 'Slim::Schema::Contributor') {
					my %p = (
						'filtertype' => 'artist',
						'customskip_parameter_1' => $item->{'item'}->id,
						'extrapopmode' => 1
					);
					Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
					$client->update();
				}elsif($blessed eq 'Slim::Schema::Genre') {
					my %p = (
						'filtertype' => 'genre',
						'customskip_parameter_1' => $item->{'item'}->id,
						'extrapopmode' => 1
					);
					Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
					$client->update();
				}else {
					$client->bumpRight();
				}
			},
		);
		Slim::Buttons::Common::pushModeLeft($client, 'INPUT.Choice', \%params);
	}
}
sub mixerFunction {
	my ($client, $noSettings) = @_;
	# look for parentParams (needed when multiple mixers have been used)
	my $paramref = defined $client->param('parentParams') ? $client->param('parentParams') : $client->modeParameterStack(-1);
	if(defined($paramref)) {
		if(!$mixTypes) {
			initFilterTypes();
		}

		my $listIndex = $paramref->{'listIndex'};
		my $items     = $paramref->{'listRef'};
		my $currentItem = $items->[$listIndex];
		my $hierarchy = $paramref->{'hierarchy'};
		my @levels    = split(",", $hierarchy);
		my $level     = $paramref->{'level'} || 0;
		my $mixerType = $levels[$level];
		if($mixerType eq 'contributor') {
			$mixerType='artist';
		}
		if($mixerType eq 'age') {
			$mixerType='album';
		}
		if($mixerType eq 'track') {
			customBrowseTrackMix($client,$currentItem);
			return;
		}elsif($mixTypes->{$mixerType}) { 
			if($mixerType eq 'album') {
				my $itemobj = objectForId('album',$currentItem->id);
				my %p = (
					'filtertype' => $mixerType,
					'item' => $itemobj,
					'customskip_parameter_1' => $currentItem->id,
					'extrapopmode' => 1
				);
				Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
				$client->update();
			}elsif($mixerType eq 'artist') {
				my $itemobj = objectForId('artist',$currentItem->id);
				my %p = (
					'filtertype' => $mixerType,
					'item' => $itemobj,
					'customskip_parameter_1' => $currentItem->id,
					'extrapopmode' => 1
				);
				Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
				$client->update();
			}elsif($mixerType eq 'genre') {
				my $itemobj = objectForId('genre',$currentItem->id);
				my %p = (
					'filtertype' => $mixerType,
					'item' => $itemobj,
					'customskip_parameter_1' => $currentItem->id,
					'extrapopmode' => 1
				);
				Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
				$client->update();
			}elsif($mixerType eq 'playlist') {
				my $itemobj = objectForId('playlist',$currentItem->id);
				my %p = (
					'filtertype' => $mixerType,
					'item' => $itemobj,
					'customskip_parameter_1' => $currentItem->id,
					'extrapopmode' => 1
				);
				Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
				$client->update();
			}elsif($mixerType eq 'year') {
				my $itemobj = objectForId('year',$currentItem->id);
				my %p = (
					'filtertype' => $mixerType,
					'item' => $itemobj,
					'customskip_parameter_1' => $currentItem->id,
					'extrapopmode' => 1
				);
				Slim::Buttons::Common::pushModeLeft($client,'PLUGIN.CustomSkipMix',\%p);
				$client->update();
			}else {
				debugMsg("Unknown mixertype = ".$mixerType."\n");
			}
		}else {
			debugMsg("No filter types found for ".$mixerType."\n");
		}
	}else {
		debugMsg("No parent parameter found\n");
	}

}

sub mixerlink {
    my $item = shift;
    my $form = shift;
    my $descend = shift;
#		debugMsg("***********************************\n");
#		for my $it (keys %$form) {
#			debugMsg("form{$it}=".$form->{$it}."\n");
#		}
#		debugMsg("***********************************\n");
	
	my $levelName = $form->{'levelName'};
	if(!$mixTypes) {
		initFilterTypes();
	}
	if(defined($levelName) && ($levelName eq 'artist' || $levelName eq 'contributor' || $levelName eq 'album' || $levelName eq 'genre' || $levelName eq 'playlist')) {
		if($levelName eq 'contributor') {
			$levelName = 'artist';
		}
		if($mixTypes->{$levelName}) {
			$form->{'filtertype'} = $levelName;
			$form->{'mixerlinks'}{'CUSTOMSKIP'} = "plugins/CustomSkip/mixerlink65.html";
		}
	}elsif(defined($levelName) && $levelName eq 'year') {
		$form->{'filtertype'} = $levelName;
	    	$form->{'yearid'} = $item->id;
		if(defined($form->{'yearid'})) {
			if($mixTypes->{$levelName}) {
				$form->{'mixerlinks'}{'CUSTOMSKIP'} = "plugins/CustomSkip/mixerlink65.html";
			}
		}
	}else {
		my $attributes = $form->{'attributes'};
		my $album;
		my $playlist = undef;
		if(defined($attributes) && $attributes =~ /\&?playlist=(\d+)/) {
			$playlist = $1;
		}elsif(defined($attributes) && $attributes =~ /\&?playlist\.id=(\d+)/) {
			$playlist = $1;
		}
		if(defined($playlist)) {
			$form->{'playlist'} = $playlist;
		}else {
			my $album;
			if(defined($form->{'levelName'}) && $form->{'levelName'} eq 'age') {
				$form->{'filtertype'} = 'album';
				$form->{'albumid'} = $item->id;
			}
		}
	
		if(defined($form->{'albumid'}) || defined($form->{'playlist'})) {
			if($mixTypes->{$form->{'filtertype'}}) {
				$form->{'mixerlinks'}{'CUSTOMSKIP'} = "plugins/CustomSkip/mixerlink65.html";
			}
		}
	}
	return $form;
}

sub mixable {
        my $class = shift;
        my $item  = shift;
	my $blessed = blessed($item);

	if(!$mixTypes) {
		initFilterTypes();
	}

	if(!$blessed) {
		return undef;
	}elsif($blessed eq 'Slim::Schema::Track') {
		return 1 if($mixTypes->{'album'} || $mixTypes->{'artist'} || $mixTypes->{'genre'});
	}elsif($blessed eq 'Slim::Schema::Year') {
		return 1 if($mixTypes->{'year'} && $item->id);
	}elsif($blessed eq 'Slim::Schema::Album') {
		return 1 if($mixTypes->{'album'});
	}elsif($blessed eq 'Slim::Schema::Age') {
		return 1 if($mixTypes->{'album'});
	}elsif($blessed eq 'Slim::Schema::Contributor') {
		return 1 if($mixTypes->{'artist'});
	}elsif($blessed eq 'Slim::Schema::Genre') {
		return 1 if($mixTypes->{'genre'});
	}elsif($blessed eq 'Slim::Schema::Playlist') {
		return 1 if($mixTypes->{'playlist'});
	}
        return undef;
}

sub initPlugin {
	my $class = shift;
	
	checkDefaults();
	Slim::Buttons::Common::addMode('PLUGIN.CustomSkip', getFunctions(), \&setMode);
	Slim::Buttons::Common::addMode('PLUGIN.CustomSkipMix', getFunctions(), \&setModeMix);
	Slim::Buttons::Common::addMode('PLUGIN.CustomSkip.ChooseParameters', getFunctions(), \&setModeChooseParameters);

	initFilterTypes();
	initFilters();
	if(scalar(keys %$filters)==0) {
		my $url = Slim::Utils::Prefs::get('plugin_customskip_directory');
		if(-e $url) {
			my %filter = (
				'id' => 'defaultfilterset.cs.xml',
				'name' => 'Default Filter Set'
			);
			saveFilter(catfile($url, "defaultfilterset.cs.xml"),\%filter);
			initFilters();
		}
	}
	my %mixerMap = ();
	if(Slim::Utils::Prefs::get("plugin_customskip_web_show_mixerlinks")) {
#		$mixerMap{'mixerlink'} = \&mixerlink;
	}
	if(Slim::Utils::Prefs::get("plugin_customskip_enable_mixerfunction")) {
		$mixerMap{'mixer'} = \&mixerFunction;
	}
	if(Slim::Utils::Prefs::get("plugin_customskip_web_show_mixerlinks") ||
		Slim::Utils::Prefs::get("plugin_customskip_enable_mixerfunction")) {

		Slim::Music::Import->addImporter($class, \%mixerMap);
	    	Slim::Music::Import->useImporter('Plugins::CustomSkip::Plugin', 1);
	}
	debugMsg("CustomSkip: Registering hook.\n");
	Slim::Control::Request::subscribe(\&newSongCallback, [['playlist'], ['newsong']]);
	Slim::Control::Request::addDispatch(['customskip','setfilter', '_filterid'], [1, 0, 0, \&setCLIFilter]);
	Slim::Utils::Scheduler::add_task(\&lateInitPlugin);
}

sub lateInitPlugin {
	initFilterTypes();
	initFilters();
	return 0;
}

sub title {
	return 'CUSTOMSKIP';
}

sub shutdownPlugin {
	if(Slim::Utils::Prefs::get("plugin_customskip_web_show_mixerlinks") ||
		Slim::Utils::Prefs::get("plugin_customskip_enable_mixerfunction")) {

		Slim::Music::Import->useImporter('Plugins::CustomSkip::Plugin', 0);
	}
	Slim::Control::Request::unsubscribe(\&newSongCallback);
}

sub webPages {

	my %pages = (
		"customskip_list\.(?:htm|xml)"     => \&handleWebList,
		"customskip_selectfilter\.(?:htm|xml)"     => \&handleWebSelectFilter,
		"customskip_disablefilter\.(?:htm|xml)"     => \&handleWebDisableFilter,
		"customskip_newfilter\.(?:htm|xml)"     => \&handleWebNewFilter,
		"customskip_savenewfilter\.(?:htm|xml)"     => \&handleWebSaveNewFilter,
		"customskip_savefilter\.(?:htm|xml)"     => \&handleWebSaveFilter,
		"customskip_newfilteritemtypes\.(?:htm|xml)"     => \&handleWebNewFilterItemTypes,
		"customskip_newfilteritem\.(?:htm|xml)"     => \&handleWebNewFilterItem,
		"customskip_savefilteritem\.(?:htm|xml)"     => \&handleWebSaveFilterItem,
		"customskip_editfilter\.(?:htm|xml)"     => \&handleWebEditFilter,
                "customskip_deletefilter\.(?:htm|xml)"     => \&handleWebDeleteFilter,
		"customskip_editfilteritem\.(?:htm|xml)"     => \&handleWebEditFilterItem,
                "customskip_deletefilteritem\.(?:htm|xml)"     => \&handleWebDeleteFilterItem,
	);

	my $value = $htmlTemplate;

	if (grep { /^CustomSkip::Plugin$/ } Slim::Utils::Prefs::getArray('disabledplugins')) {

		$value = undef;
	} 

	#Slim::Web::Pages->addPageLinks("browse", { 'PLUGIN_CUSTOMSKIP' => $value });

	return (\%pages,$value);
}

sub setCLIFilter {
	debugMsg("Entering setCLIFilter\n");
	my $request = shift;
	my $client = $request->client();
	
	if ($request->isNotCommand([['customskip'],['setfilter']])) {
		debugMsg("Incorrect command\n");
		$request->setStatusBadDispatch();
		debugMsg("Exiting setCLIFilter\n");
		return;
	}
	if(!defined $client) {
		debugMsg("Client required\n");
		$request->setStatusNeedsClient();
		debugMsg("Exiting setCLIFilter\n");
		return;
	}

	# get our parameters
  	my $filterId    = $request->getParam('_filterid');
  	if(!defined $filterId || $filterId eq '') {
		debugMsg("_filterid not defined\n");
		$request->setStatusBadParams();
		debugMsg("Exiting setCLIFilter\n");
		return;
  	}
  	
	initFilters();

	if(!defined($filters->{$filterId})) {
		debugMsg("Unknown filter $filterId\n");
		$request->setStatusBadParams();
		debugMsg("Exiting setCLIFilter\n");
		return;
  	}
	my $key = $client;
	if(defined($client->syncgroupid)) {
		$key = "SyncGroup".$client->syncgroupid;
	}
	$currentFilter{$key} = $filterId;
	$client->prefSet('plugin_customskip_filter',$filterId);

	$request->addResult('filter', $filterId);
	$request->setStatusDone();
	debugMsg("Exiting setCLIFilter\n");
}


sub newSongCallback 
{
	my $request = shift;
	my $client = undef;
	my $command = undef;
	
	return unless Slim::Utils::Prefs::get('plugin_customskip_global_skipping');
	$client = $request->client();	
	if (defined($client) && !defined($client->master) && $request->getRequest(0) eq 'playlist') {
		$command = $request->getRequest(1);
		my $track  = Slim::Player::Playlist::song($client);
		if (defined $track) {
			debugMsg("Received newsong for ".$track->url."\n");
			my $dbh = getCurrentDBH();
			my $sth = $dbh->prepare('select dynamicplaylist_history.id from dynamicplaylist_history where client=? and id=?');

			my $result = 0;
			eval {
				$sth->bind_param(1, $client->macaddress() , SQL_VARCHAR);
				$sth->bind_param(2, $track->id , SQL_INTEGER);
				$sth->execute();
				if( $sth->fetch() ) {
					$result = 1;
				}
			};
			if ($@) {
				$result = 1;
				debugMsg("Error executing SQL: $@\n$DBI::errstr\n");
			}
			$sth->finish();
			my $keep = 1;
			if(!$result) {
				$keep = executeDynamicPlayListFilter($client,undef,$track);
			}
			if(!$keep) {
				$client->execute(["playlist", "deleteitem", $track->url]);
				debugMsg("Removing song from client playlist\n");
			}
		}
	}	
}

sub getCurrentFilter {
	my $client = shift;
	if(defined($client)) {
		if(!$filters) {
			initFilterTypes();
			initFilters();
		}
		my $key = $client;
		if(defined($client->syncgroupid)) {
			$key = "SyncGroup".$client->syncgroupid;
		}
		if(defined($currentFilter{$key})) {
			return $filters->{$currentFilter{$key}};
		}else {
			my $filter = $client->prefGet('plugin_customskip_filter');
			if(defined($filter) && defined($filters->{$filter})) {
				$currentFilter{$key} = $filter;
				return $filters->{$filter};
			}else {
				if(scalar(keys %$filters)==1 && defined($filters->{'defaultfilterset.cs.xml'})) {
					my $filteritems = $filters->{'defaultfilterset.cs.xml'}->{'filter'};
					if(!defined($filteritems) || scalar(@$filteritems)==0) {
						$currentFilter{$key} = 'defaultfilterset.cs.xml';
						$client->prefSet('plugin_customskip_filter','defaultfilterset.cs.xml');
					}
				}
			}
		}	
	}
	return undef;
}

# Draws the plugin's web page
sub handleWebList {
	my ($client, $params) = @_;

	# Pass on the current pref values and now playing info
	#initFilters();

	$params->{'pluginCustomSkipFilters'} = getFilters($client);
	$params->{'pluginCustomSkipActiveFilter'} = getCurrentFilter($client);
	if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
	}
	
	$params->{'pluginCustomSkipVersion'} = $PLUGINVERSION;

	return Slim::Web::HTTP::filltemplatefile($htmlTemplate, $params);
}

sub handleWebSelectFilter {
	my ($client, $params) = @_;
	initFilters();

	if(defined($client) && defined($params->{'filter'}) && defined($filters->{$params->{'filter'}})) {
		my $key = $client;
		if(defined($client->syncgroupid)) {
			$key = "SyncGroup".$client->syncgroupid;
		}
		$currentFilter{$key} = $params->{'filter'};
		$client->prefSet('plugin_customskip_filter',$params->{'filter'});
	}
	return handleWebList($client,$params);
}

sub handleWebDisableFilter {
	my ($client, $params) = @_;
	if(defined($client)) {
		my $key = $client;
		if(defined($client->syncgroupid)) {
			$key = "SyncGroup".$client->syncgroupid;
		}
		$currentFilter{$key} = undef;
		$client->prefSet('plugin_customskip_filter',0);
	}
	return handleWebList($client,$params);
}

sub handleWebNewFilter {
	my ($client, $params) = @_;

	# Pass on the current pref values and now playing info
	#initFilters();

	if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
	}
	
	return Slim::Web::HTTP::filltemplatefile('plugins/CustomSkip/customskip_newfilter.html', $params);
}

sub handleWebSaveNewFilter {
	my ($client, $params) = @_;

	# Pass on the current pref values and now playing info
	initFilters();

	my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
	
	if (!defined $browseDir || !-d $browseDir) {
		$params->{'pluginCustomSkipError'} = 'No custom skip directory configured';
	}
	my $file = unescape($params->{'file'});
	if(defined($file) && $file ne '' && !($file =~ /^.*\..*$/)) {
		$file .=".cs.xml";
		$params->{'file'} = $params->{'file'}.".cs.xml";
	}
	my $url = catfile($browseDir, $file);
	
	if(!defined($params->{'pluginCustomSkipError'}) && -e $url) {
		$params->{'pluginCustomSkipError'} = 'Invalid filename, file already exist';
	}

	my %filter = (
		'id' => $file,
		'name' => $params->{'name'}
	);
	my $error = saveFilter($url, \%filter);
	if(defined($error)) {
		$params->{'pluginCustomSkipError'} = $error;
	}
	if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
	}
	initFilters();
	if(defined($params->{'pluginCustomSkipError'})) {
		$params->{'pluginCustomSkipEditFilterName'} = $params->{'name'};
		$params->{'pluginCustomSkipEditFilterFileName'} = $params->{'file'};		
		return Slim::Web::HTTP::filltemplatefile('plugins/CustomSkip/customskip_newfilter.html', $params);
	}else {
		$params->{'filter'} = $file;
		return handleWebNewFilterItemTypes($client,$params);
	}
}

sub handleWebSaveFilter {
	my ($client, $params) = @_;

	# Pass on the current pref values and now playing info
	initFilters();

	my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
	
	if (!defined $browseDir || !-d $browseDir) {
		$params->{'pluginCustomSkipError'} = 'No custom skip directory configured';
	}
	my $file = unescape($params->{'filter'});
	my $url = catfile($browseDir, $file);
	
	if(!defined($params->{'pluginCustomSkipError'}) && !(-e $url)) {
		$params->{'pluginCustomSkipError'} = 'Invalid filename, file dont exist';
	}

	if(defined($params->{'name'})) {
		my $filter = $filters->{$params->{'filter'}};
		$filter->{'name'} = $params->{'name'};
		my $error = saveFilter($url, $filter);
		if(defined($error)) {
			$params->{'pluginCustomSkipError'} = $error;
		}
	}

	if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
	}
	initFilters();
	return handleWebEditFilter($client,$params);
}

sub handleWebNewFilterItemTypes {
	my ($client, $params) = @_;
	if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
	}
	$params->{'pluginCustomSkipFilterTypes'} = getFilterTypes($client,$params);
	$params->{'pluginCustomSkipFilter'} = $filters->{$params->{'filter'}};
	return Slim::Web::HTTP::filltemplatefile('plugins/CustomSkip/customskip_newfilteritemtypes.html', $params);
}

sub handleWebNewFilterItem {
	my ($client, $params) = @_;
	if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
	}
	my $filterType = $filterTypes->{$params->{'filtertype'}};
	my $parameters = $filterType->{'customskipparameters'};
	my @parametersToSelect = ();
	for my $p (@$parameters) {
		if(defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
			addValuesToFilterParameter($p);
			push @parametersToSelect,$p;
		}
	}
	$params->{'pluginCustomSkipFilter'} = $filters->{$params->{'filter'}};
	$params->{'pluginCustomSkipFilterType'} = $filterType;
	$params->{'pluginCustomSkipFilterParameters'} = \@parametersToSelect;
	return Slim::Web::HTTP::filltemplatefile('plugins/CustomSkip/customskip_editfilteritem.html', $params);
}

sub handleWebSaveFilterItem {
	my ($client, $params) = @_;

	# Pass on the current pref values and now playing info
	initFilters();
	my $filter = $filters->{$params->{'filter'}};

	my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
	
	if (!defined $browseDir || !-d $browseDir) {
		$params->{'pluginCustomSkipError'} = 'No custom skip directory configured';
	}
	my $file = unescape($params->{'filter'});
	my $url = catfile($browseDir, $file);
	
	if(!defined($params->{'pluginCustomSkipError'}) && !(-e $url)) {
		$params->{'pluginCustomSkipError'} = 'Invalid filename, file doesnt exist';
	}

	saveFilterItemWeb($client,$params,$url,$filter);
	if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
	}
	initFilters();
	if(defined($params->{'pluginCustomSkipError'})) {
		return Slim::Web::HTTP::filltemplatefile('plugins/CustomSkip/customskip_editfilteritem.html', $params);
	}else {
		$params->{'filter'} = $file;
		return handleWebEditFilter($client,$params);
	}
}

sub handleWebDeleteFilter {
	my ($client, $params) = @_;
        if ($::VERSION ge '6.5') {
                $params->{'pluginCustomSkipSlimserver65'} = 1;
        }
	my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
	my $file = unescape($params->{'filter'});
	my $url = catfile($browseDir, $file);
	if(defined($browseDir) && -d $browseDir && $file && -e $url) {
		unlink($url) or do {
			warn "Unable to delete file: ".$url.": $! \n";
		}
	}		
	initFilters();
        return handleWebList($client,$params);
}

sub handleWebEditFilter {
        my ($client, $params) = @_;

	initFilters();

        if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
        }
	my $filterId = $params->{'filter'};
	if(defined($filterId) && defined($filters->{$filterId})) {
		my $filter = $filters->{$filterId};
		my $filterItems = $filter->{'filter'};
		$params->{'pluginCustomSkipFilterItems'} = $filterItems;
		$params->{'pluginCustomSkipFilter'} = $filter;
		return Slim::Web::HTTP::filltemplatefile('plugins/CustomSkip/customskip_editfilter.html', $params);
	}
	return handleWebList($client,$params);
}

sub handleWebDeleteFilterItem {
	my ($client, $params) = @_;
        if ($::VERSION ge '6.5') {
                $params->{'pluginCustomSkipSlimserver65'} = 1;
        }
	my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
	if (!defined $browseDir || !-d $browseDir) {
		$params->{'pluginCustomSkipError'} = 'No custom skip directory configured';
	}
	my $file = unescape($params->{'filter'});
	my $url = catfile($browseDir, $file);
	if(!defined($params->{'pluginCustomSkipError'}) && !(-e $url)) {
		$params->{'pluginCustomSkipError'} = 'Invalid filename, file doesnt exist';
	}

	my $filter = $filters->{$params->{'filter'}};
	my $filteritems = $filter->{'filter'};
	my $deleteFilterItem = $params->{'filteritem'} - 1;

	splice(@$filteritems,$deleteFilterItem,1);
	$filter->{'filter'} = $filteritems;

	saveFilter($url,$filter);
        return handleWebEditFilter($client,$params);
}

sub handleWebEditFilterItem {
        my ($client, $params) = @_;

        if ($::VERSION ge '6.5') {
		$params->{'pluginCustomSkipSlimserver65'} = 1;
        }
	my $filterId = $params->{'filter'};
	if(defined($filterId) && defined($filters->{$filterId})) {
		my $filter = $filters->{$filterId};
		my $filteritems = $filter->{'filter'};
		my $filterItem = $filteritems->[$params->{'filteritem'}-1];
		my $filterType = $filterTypes->{$filterItem->{'id'}};
		if(defined($filterType)) {
			my %currentParameterValues = ();
			my $filterItemParameters = $filterItem->{'parameter'};
			for my $p (@$filterItemParameters) {
				my $values = $p->{'value'};
				my %valuesHash = ();
				for my $v (@$values) {
					$valuesHash{$v} = $v;
				}
				if(!%valuesHash) {
					$valuesHash{''} = '';
				}
				$currentParameterValues{$p->{'id'}} = \%valuesHash;
			}
			if(defined($filterType->{'customskipparameters'})) {
				my $parameters = $filterType->{'customskipparameters'};
				my @parametersToSelect = ();
				for my $p (@$parameters) {
					if(defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
						addValuesToFilterParameter($p,$currentParameterValues{$p->{'id'}});
						push @parametersToSelect,$p;
					}
				}
				$params->{'pluginCustomSkipFilter'} = $filter;
				$params->{'pluginCustomSkipFilterType'} = $filterType;
				$params->{'pluginCustomSkipFilterParameters'} = \@parametersToSelect;
			}
			return Slim::Web::HTTP::filltemplatefile('plugins/CustomSkip/customskip_editfilteritem.html', $params);
		}
	}
	return handleWebEditFilter($client,$params);
}

sub saveFilterItemWeb {
	my ($client, $params, $url, $filter) = @_;
	my $fh;

	if(!($params->{'pluginCustomSkipError'})) {
		my $filterType = $filterTypes->{$params->{'filtertype'}};
		my %filterParameters = ();
		my $data = "";
		my @parametersToSave = ();
		if(defined($filterType->{'customskipparameters'})) {
			my $parameters = $filterType->{'customskipparameters'};
			for my $p (@$parameters) {
				if(defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
					addValuesToFilterParameter($p);
					my $values = getValueOfFilterParameterWeb($params,$p,"&<>\'\"");
					if(scalar(@$values)>0) {
						my $j = 0;
						for my $value (@$values) {
							$values->[$j] = decode_entities($value);
						}
						my %savedParameter = (
							'id' => $p->{'id'},
							'value' => $values
						);
						push @parametersToSave, \%savedParameter;
					}
				}
			}
		}
		my $filterItems = $filter->{'filter'};
		my %newFilterItem = (
			'id' => $filterType->{'id'},
			'parameter' => \@parametersToSave
		);
		if(defined($params->{'filteritem'}) && !defined($params->{'newfilteritem'})) {
			splice(@$filterItems,$params->{'filteritem'}-1,1,\%newFilterItem);
		}else {
			push @$filterItems,\%newFilterItem;
		}
		$filter->{'filter'} = $filterItems;
		my $error = saveFilter($url,$filter);
		if(defined($error)) {
			$params->{'pluginCustomSkipError'} = $error;
		}
	}
	
	if($params->{'pluginCustomSkipError'}) {
		my %parameters;
		for my $p (keys %$params) {
			if($p =~ /^filterparameter_/) {
				$parameters{$p}=$params->{$p};
			}
		}		
		$params->{'pluginCustomSkipFilterParameters'} = \%parameters;
		$params->{'pluginCustomSkipFilterType'} = $params->{'filtertype'};
		if ($::VERSION ge '6.5') {
			$params->{'pluginCustomSkipSlimserver65'} = 1;
		}
		return undef;
	}else {
		return 1;
	}
}

sub saveFilter {
	my ($url, $filter) = @_;

	my $fh;

	if(!($url =~ /.*\.cs\.xml$/)) {
		return 'Filename must end with .cs.xml';
	}
	my $data = "";
	$data .= "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<customskip>\n\t<name>".encode_entities($filter->{'name'},"&<>\'\"")."</name>\n";
	my $filterItems = $filter->{'filter'};
	for my $filterItem (@$filterItems) {
		$data .= "\t<filter>\n\t\t<id>".$filterItem->{'id'}."</id>\n";
		my $parameters = $filterItem->{'parameter'};
		if(scalar(@$parameters)>0) {
			for my $parameter (@$parameters) {
				$data .= "\t\t<parameter>\n\t\t\t<id>".$parameter->{'id'}."</id>\n";
				my $values = $parameter->{'value'};
				if(scalar(@$values)>0) {
					for my $value  (@$values) {
						$data .= "\t\t\t<value>".encode_entities($value)."</value>\n";
					}
				}
				$data .= "\t\t</parameter>\n";
			}
		}
		$data .= "\t</filter>\n";
	}
	$data .= "</customskip>\n";

	debugMsg("Opening browse configuration file: $url\n");
	open($fh,"> $url") or do {
            return 'Error saving filter';
	};
	debugMsg("Writing to file: $url\n");
	print $fh $data;
	debugMsg("Writing to file succeeded\n");
	close $fh;

	return undef;
}

sub addValuesToFilterParameter {
	my $p = shift;
	my $currentValues = shift;

	if($p->{'type'} =~ '^sql.*') {
		my $listValues = getSQLTemplateData($p->{'data'});
		if(defined($currentValues)) {
			for my $v (@$listValues) {
				if($currentValues->{$v->{'value'}}) {
					$v->{'selected'} = 1;
				}
			}
		}elsif(defined($p->{'value'})) {
			for my $v (@$listValues) {
				if($p->{'value'} eq $v->{'value'}) {
					$v->{'selected'} = 1;
				}
			}
		}
		$p->{'values'} = $listValues;
	}elsif($p->{'type'} =~ '.*multiplelist$' || $p->{'type'} =~ '.*singlelist$' || $p->{'type'} =~ '.*checkboxes$') {
		my @listValues = ();
		my @values = split(/,/,$p->{'data'});
		for my $value (@values){
			my @idName = split(/=/,$value);
			my %listValue = (
				'id' => @idName->[0],
				'name' => @idName->[1]
			);
			if(scalar(@idName)>2) {
				$listValue{'value'} = @idName->[2];
			}else {
				$listValue{'value'} = @idName->[0];
			}
			push @listValues, \%listValue;
		}
		if(defined($currentValues)) {
			for my $v (@listValues) {
				if($currentValues->{$v->{'value'}}) {
					$v->{'selected'} = 1;
				}
			}
		}elsif(defined($p->{'value'})) {
			for my $v (@listValues) {
				if($p->{'value'} eq $v->{'value'}) {
					$v->{'selected'} = 1;
				}
			}
		}
		$p->{'values'} = \@listValues;
	}elsif($p->{'type'} =~ '.*timelist$') {
		my @listValues = ();
		my @values = split(/,/,$p->{'data'});
		my $currentTime = time();
		for my $value (@values){
			my @idName = split(/=/,$value);
			my $itemTime = undef;
			my $itemName = undef;
			if(@idName->[0]==0) {
				$itemTime = 0;
				$itemName = "Forever";
			}else {
				$itemTime = $currentTime+@idName->[0];
				$itemName = @idName->[1].' ('.Slim::Utils::DateTime::shortDateF($itemTime).' '.Slim::Utils::DateTime::timeF($itemTime).')';
			}
			my %listValue = (
				'id' => $itemTime,
				'name' => $itemName
			);
			if((!defined($currentValues) || defined($currentValues->{0})) && $p->{'value'} eq @idName->[0]) {
				$listValue{'selected'} = 1;
			}
			push @listValues, \%listValue;
		}
		if(defined($currentValues)) {
			for my $value (keys %$currentValues) {
				if($value!=0) {
					my $itemTime = $value;
					my $itemName = Slim::Utils::DateTime::shortDateF($itemTime).' '.Slim::Utils::DateTime::timeF($itemTime);
					my %listValue = (
						'id' => $itemTime,
						'name' => $itemName,
						'selected' => 1
					);
					push @listValues, \%listValue;
				}
			}
		}
		$p->{'values'} = \@listValues;
	}elsif(defined($currentValues)) {
		for my $v (keys %$currentValues) {
			$p->{'value'} = $v;
		}
	}
}

sub getValueOfFilterParameterWeb {
	my $params = shift;
	my $parameter = shift;
	my $encodeentities = shift;

	my $dbh = getCurrentDBH();
	if($parameter->{'type'} =~ /.*multiplelist$/ || $parameter->{'type'} =~ /.*checkboxes$/) {
		my $selectedValues = undef;
		if($parameter->{'type'} =~ /.*multiplelist$/) {
			$selectedValues = getMultipleListQueryParameter($params,'filterparameter_'.$parameter->{'id'});
		}else {
			$selectedValues = getCheckBoxesQueryParameter($params,'filterparameter_'.$parameter->{'id'});
		}
		my $values = $parameter->{'values'};
		my @result = ();
		for my $item (@$values) {
			if(defined($selectedValues->{$item->{'id'}})) {
				if(defined($encodeentities)) {
					$item->{'value'} = encode_entities($item->{'value'},$encodeentities);
				}
				if($parameter->{'quotevalue'}) {
					push @result,$item->{'value'};
				}else {
					push @result,$item->{'value'};
				}
			}
		}
		return \@result;
	}elsif($parameter->{'type'} =~ /.*singlelist$/) {
		my $values = $parameter->{'values'};
		my $selectedValue = $params->{'filterparameter_'.$parameter->{'id'}};
		my @result = ();
		for my $item (@$values) {
			if($selectedValue eq $item->{'id'}) {
				if(defined($encodeentities)) {
					$item->{'value'} = encode_entities($item->{'value'},$encodeentities);
				}
				if($parameter->{'quotevalue'}) {
					push @result,$item->{'value'};
				}else {
					push @result,$item->{'value'};
				}
				last;
			}
		}
		return \@result;
	}elsif($parameter->{'type'} =~ /.*timelist$/) {
		my @result = ();
		my $selectedValue = $params->{'filterparameter_'.$parameter->{'id'}};
		push @result,$selectedValue;
		return \@result;
	}else{
		my @result = ();
		if(defined($params->{'filterparameter_'.$parameter->{'id'}}) && $params->{'filterparameter_'.$parameter->{'id'}} ne '') {
			my $value = $params->{'filterparameter_'.$parameter->{'id'}};
			if(defined($encodeentities)) {
				$value = encode_entities($value,$encodeentities);
			}
			if($parameter->{'quotevalue'}) {
				push @result, $value;
			}else {
				push @result, $value;
			}
		}
		return \@result;
	}
}

sub getValueOfFilterParameter {
	my $client = shift;
	my $parameter = shift;
	my $parameterNo = shift;
	my $encodeentities = shift;

	my $dbh = getCurrentDBH();
	if($parameter->{'type'} =~ /.*multiplelist$/ || $parameter->{'type'} =~ /.*checkboxes$/) {
		my $selectedValue = undef;
		if($parameter->{'type'} =~ /.*multiplelist$/) {
			$selectedValue = $client->param('customskip_parameter_'.$parameterNo);
		}else {
			$selectedValue = $client->param('customskip_parameter_'.$parameterNo);
		}

		my $values = $parameter->{'values'};
		my @result = ();
		for my $item (@$values) {
			if($selectedValue eq $item->{'id'}) {
				if(defined($encodeentities)) {
					$item->{'value'} = encode_entities($item->{'value'},$encodeentities);
				}
				if($parameter->{'quotevalue'}) {
					push @result,$item->{'value'};
				}else {
					push @result,$item->{'value'};
				}
			}
		}
		return \@result;

	}elsif($parameter->{'type'} =~ /.*singlelist$/) {
		my $selectedValue = $client->param('customskip_parameter_'.$parameterNo);
		my $values = $parameter->{'values'};
		my @result = ();
		for my $item (@$values) {
			if($selectedValue eq $item->{'id'}) {
				if(defined($encodeentities)) {
					$item->{'value'} = encode_entities($item->{'value'},$encodeentities);
				}
				if($parameter->{'quotevalue'}) {
					push @result,$item->{'value'};
				}else {
					push @result,$item->{'value'};
				}
			}
		}
		return \@result;
	}elsif($parameter->{'type'} =~ /.*timelist$/) {
		my @result = ();
		my $selectedValue = $client->param('customskip_parameter_'.$parameterNo);
		push @result,$selectedValue;
		return \@result;
	}else{
		my @result = ();
		my $selectedValue = $client->param('customskip_parameter_'.$parameterNo);
		push @result,$selectedValue;
		return \@result;
	}
}

sub getMultipleListQueryParameter {
	my $params = shift;
	my $parameter = shift;

	my $query = $params->{url_query};
	my %result = ();
	if($query) {
		foreach my $param (split /\&/, $query) {
			if ($param =~ /([^=]+)=(.*)/) {
				my $name  = unescape($1);
				my $value = unescape($2);
				if($name eq $parameter) {
					# We need to turn perl's internal
					# representation of the unescaped
					# UTF-8 string into a "real" UTF-8
					# string with the appropriate magic set.
					if ($value ne '*' && $value ne '') {
						$value = Slim::Utils::Unicode::utf8on($value);
						$value = Slim::Utils::Unicode::utf8encode_locale($value);
					}
					$result{$value} = 1;
				}
			}
		}
	}
	return \%result;
}

sub getCheckBoxesQueryParameter {
	my $params = shift;
	my $parameter = shift;

	my %result = ();
	foreach my $key (keys %$params) {
		my $pattern = '^'.$parameter.'_(.*)';
		if ($key =~ /$pattern/) {
			my $id  = unescape($1);
			$result{$id} = 1;
		}
	}
	return \%result;
}

sub getSQLTemplateData {
	my $sqlstatements = shift;
	my @result =();
	my $ds = getCurrentDS();
	my $dbh = getCurrentDBH();
	my $trackno = 0;
	my $sqlerrors = "";
    	for my $sql (split(/[;]/,$sqlstatements)) {
    	eval {
			$sql =~ s/^\s+//g;
			$sql =~ s/\s+$//g;
			my $sth = $dbh->prepare( $sql );
			debugMsg("Executing: $sql\n");
			$sth->execute() or do {
	            debugMsg("Error executing: $sql\n");
	            $sql = undef;
			};

	        if ($sql =~ /^SELECT+/oi) {
				debugMsg("Executing and collecting: $sql\n");
				my $id;
                                my $name;
                                my $value;
				$sth->bind_col( 1, \$id);
                                $sth->bind_col( 2, \$name);
                                $sth->bind_col( 3, \$value);
				while( $sth->fetch() ) {
                                    my %item = (
                                        'id' => $id,
                                        'name' => Slim::Utils::Unicode::utf8decode($name,'utf8'),
					'value' => Slim::Utils::Unicode::utf8decode($value,'utf8')
                                    );
                                    push @result, \%item;
				}
			}
			$sth->finish();
		};
		if( $@ ) {
		    warn "Database error: $DBI::errstr\n";
		}		
	}
	return \@result;
}

sub getFilters {
	my $client = shift;
	my @result = ();
	
	initFilters($client);
	foreach my $key (keys %$filters) {
		my $filter = $filters->{$key};
		debugMsg("Adding filter: ".$filter->{'id'}."\n");
		push @result, $filter;
	}
	@result = sort { $a->{'name'} cmp $b->{'name'} } @result;
	return \@result;
}

sub getAvailableFilters {
	my $client = shift;
	my @result = ();
	
	initFilters($client);
	foreach my $key (keys %$filters) {
		my $filter = $filters->{$key};
		my %item = (
			'id' => $key,
			'name' => $filter->{'name'},
			'value' => $key
		);
		push @result, \%item;
	}
	@result = sort { $a->{'name'} cmp $b->{'name'} } @result;
	return \@result;
}

sub getFilterTypes {
	my $client = shift;
	my $params = shift;
	my @result = ();
	
	initFilterTypes($client);
	foreach my $key (keys %$filterTypes) {
		my $filterType = $filterTypes->{$key};
		push @result, $filterType;
	}
	@result = sort { $a->{'name'} cmp $b->{'name'} } @result;
	return \@result;
}

sub initFilters {
	my $client = shift;

	my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
	debugMsg("Searching for custom skip configuration in: $browseDir\n");
	initFilterTypes($client);

	my %localFilters = ();
	if (!defined $browseDir || !-d $browseDir) {
		debugMsg("Skipping custom skip configuration scan - directory is undefined\n");
	}else {
		readFiltersFromDir($client,$browseDir,\%localFilters, $filterTypes);
	}
    
	for my $key (keys %localFilters) {
		my $filter = $localFilters{$key};
		removeExpiredFilterItems($filter);
	}
	$filters = \%localFilters;
}

sub removeExpiredFilterItems {
	my $filter = shift;

	my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
	return unless defined $browseDir && -d $browseDir;

	my $filteritems = $filter->{'filter'};
	my @removeItems = ();
	my $i = 0;
	for my $filteritem (@$filteritems) {
		my $parameters = $filteritem->{'parameter'};
		for my $p (@$parameters) {
			if($p->{'id'} eq 'customskipvalidtime') {
				my $values = $p->{'value'};
				if(defined($values) && scalar(@$values)>0 && $values->[0]>0) {
					if($values->[0] < time()) {
						debugMsg("Remove expired filter item ".($i+1)."\n");
						push @removeItems,$i;
					}
				}
			}
		}
		$i = $i + 1;
	}
	if(scalar(@removeItems)>0) {
		my $i=0;
		for my $index (@removeItems) {
			splice(@$filteritems,$index-$i,1);
			$i = $i - 1;
		}
		$filter->{'filter'} = $filteritems;
		my $browseDir = Slim::Utils::Prefs::get("plugin_customskip_directory");
		if (defined $browseDir || -d $browseDir) {
			my $file = unescape($filter->{'id'});
			my $url = catfile($browseDir, $file);
			if(-e $url) {
				saveFilter($url,$filter);
			}
		}
	}
}
sub readFiltersFromDir {
	my $client = shift;
	my $browseDir = shift;
	my $localFilters = shift;
	my $filterTypes = shift;
	debugMsg("Loading skip configuration from: $browseDir\n");

	my @dircontents = Slim::Utils::Misc::readDirectory($browseDir,"cs.xml");
	for my $item (@dircontents) {

		next if -d catdir($browseDir, $item);

		my $path = catfile($browseDir, $item);

		# read_file from File::Slurp
		my $content = eval { read_file($path) };
		if ( $content ) {
			my $errorMsg = parseFilterContent($client,$item,$content,$localFilters,$filterTypes);
			if($errorMsg) {
				errorMsg("CustomSkip: Unable to open configuration file: $path\n$errorMsg\n");
			}
		}else {
			if ($@) {
				errorMsg("CustomSkip: Unable to open configuration file: $path\nBecause of:\n$@\n");
			}else {
				errorMsg("CustomSkip: Unable to open configuration file: $path\n");
			}
		}
	}
}

sub parseFilterContent {
	my $client = shift;
	my $item = shift;
	my $content = shift;
	my $localFilters = shift;
	my $filterTypes = shift;
	my $dbh = getCurrentDBH();

	my $filterId = $item;
	my $errorMsg = undef;
        if ( $content ) {
		$content = Slim::Utils::Unicode::utf8decode($content,'utf8');
		my $xml = eval { XMLin($content, forcearray => ["filter","parameter","value"], keyattr => []) };
		#debugMsg(Dumper($valuesXml));
		if ($@) {
			$errorMsg = "$@";
			errorMsg("CustomSkip: Failed to parse configuration because:\n$@\n");
		}else {
			my $filters = $xml->{'filter'};
			$xml->{'id'} = $filterId;
			for my $filter (@$filters) {
				my $filterType = $filterTypes->{$filter->{'id'}};
				if(defined($filterType)) {
					my $displayName = $filterType->{'name'};
					my %filterParameters = ();
					my $parameters = $filter->{'parameter'};
					for my $p (@$parameters) {
						my $values = $p->{'value'};
						my $value = '';
						for my $v (@$values) {
							if($value ne '') {
								$value .= ',';
							}
							if($p->{'quotevalue'}) {
								$value .= $dbh->quote(encode_entities($v));
							}else {
								$value .= encode_entities($v);
							}
						}
						#debugMsg("Setting: ".$p->{'id'}."=".$value."\n");
						$filterParameters{$p->{'id'}}=$value;
					}
					if(defined($filterType->{'customskipparameters'})) {
						my $parameters = $filterType->{'customskipparameters'};
						for my $p (@$parameters) {
							if(defined($p->{'type'}) && defined($p->{'id'}) && defined($p->{'name'})) {
								if(!defined($filterParameters{$p->{'id'}})) {
									my $value = $p->{'value'};
									if(!defined($value)) {
										$value='';
									}
									debugMsg("Setting default value ".$p->{'id'}."=".$value."\n");
									$filterParameters{$p->{'id'}} = $value;
								}
							}
						}
					}
					$displayName .= ' ';
					my $displayParameters = $filterType->{'customskipparameters'};
					for my $p (@$displayParameters) {
						my $displayed = 0;
						if(defined($filterParameters{$p->{'id'}})) {
							if($p->{'id'} eq 'customskippercentage') {
								if($filterParameters{$p->{'id'}}<100) {
									$displayName .= $filterParameters{$p->{'id'}}."%";
									$displayed = 1;
								}
							}elsif($p->{'type'} =~ '.*timelist$') {
								if($filterParameters{$p->{'id'}}>0) {
									$displayName .= Slim::Utils::DateTime::shortDateF($filterParameters{$p->{'id'}}).' '.Slim::Utils::DateTime::timeF($filterParameters{$p->{'id'}});
									$displayed = 1;

								}
							}else {
								$displayName .= decode_entities($filterParameters{$p->{'id'}});
								$displayed = 1;
							}
							if($displayed) {
								$displayName .= ', ';
							}
						}
					}
					$filter->{'displayname'} = $displayName;
					$filter->{'parametervalues'} = \%filterParameters;

				}else {
					debugMsg("Skipping unknown filter type: ".$filter->{'id'}."\n");
				}
			}
	                $localFilters->{$filterId} = $xml;
	    
			# Release content
			undef $content;
		}
	}else {
		$errorMsg = "Incorrect information in skip data";
		errorMsg("CustomSkip: Unable to to read skip configuration\n");
	}
	return $errorMsg;
}

sub getFunctions {
	# Functions to allow mapping of mixes to keypresses
	return {
		'up' => sub  {
			my $client = shift;
			$client->bumpUp();
		},
		'down' => sub  {
			my $client = shift;
			$client->bumpDown();
		},
		'left' => sub  {
			my $client = shift;
			Slim::Buttons::Common::popModeRight($client);
		},
		'right' => sub  {
			my $client = shift;
			$client->bumpRight();
		}
	}
}

sub checkDefaults {
	my $prefVal = Slim::Utils::Prefs::get('plugin_customskip_showmessages');
	if (! defined $prefVal) {
		debugMsg("Defaulting plugin_customskip_showmessages to 0\n");
		Slim::Utils::Prefs::set('plugin_customskip_showmessages', 0);
	}
	$prefVal = Slim::Utils::Prefs::get('plugin_customskip_global_skipping');
	if (! defined $prefVal) {
		debugMsg("Defaulting plugin_customskip_global_skipping to 0\n");
		Slim::Utils::Prefs::set('plugin_customskip_global_skipping', 0);
	}
        $prefVal = Slim::Utils::Prefs::get('plugin_customskip_directory');
	if (! defined $prefVal) {
		my $dir=Slim::Utils::Prefs::get('playlistdir');
		debugMsg("Defaulting plugin_customskip_directory to:$dir\n");
		Slim::Utils::Prefs::set('plugin_customskip_directory', $dir);
	}
        $prefVal = Slim::Utils::Prefs::get('plugin_customskip_enable_mixerfunction');
	if (! defined $prefVal) {
		debugMsg("Defaulting plugin_customskip_enable_mixerfunction to: 1\n");
		Slim::Utils::Prefs::set('plugin_customskip_enable_mixerfunction', 1);
	}
        $prefVal = Slim::Utils::Prefs::get('plugin_customskip_web_show_mixerlinks');
	if (! defined $prefVal) {
		debugMsg("Defaulting plugin_customskip_web_show_mixerlinks to: 1\n");
		Slim::Utils::Prefs::set('plugin_customskip_web_show_mixerlinks', 1);
	}
}

sub setupGroup
{
	my %setupGroup =
	(
	 PrefOrder => ['plugin_customskip_directory','plugin_customskip_web_show_mixerlinks','plugin_customskip_enable_mixerfunction','plugin_customskip_global_skipping','plugin_customskip_showmessages'],
	 GroupHead => string('PLUGIN_CUSTOMSKIP_SETUP_GROUP'),
	 GroupDesc => string('PLUGIN_CUSTOMSKIP_SETUP_GROUP_DESC'),
	 GroupLine => 1,
	 GroupSub  => 1,
	 Suppress_PrefSub  => 1,
	 Suppress_PrefLine => 1
	);
	my %setupPrefs =
	(
	plugin_customskip_showmessages => {
			'validate'     => \&validateTrueFalseWrapper
			,'PrefChoose'  => string('PLUGIN_CUSTOMSKIP_SHOW_MESSAGES')
			,'changeIntro' => string('PLUGIN_CUSTOMSKIP_SHOW_MESSAGES')
			,'options' => {
					 '1' => string('ON')
					,'0' => string('OFF')
				}
			,'currentValue' => sub { return Slim::Utils::Prefs::get("plugin_customskip_showmessages"); }
		},		
	plugin_customskip_global_skipping => {
			'validate'     => \&validateTrueFalseWrapper
			,'PrefChoose'  => string('PLUGIN_CUSTOMSKIP_GLOBAL_SKIPPING')
			,'changeIntro' => string('PLUGIN_CUSTOMSKIP_GLOBAL_SKIPPING')
			,'options' => {
					 '1' => string('ON')
					,'0' => string('OFF')
				}
			,'currentValue' => sub { return Slim::Utils::Prefs::get("plugin_customskip_global_skipping"); }
		},		
	plugin_customskip_web_show_mixerlinks => {
			'validate'     => \&validateTrueFalseWrapper
			,'PrefChoose'  => string('PLUGIN_CUSTOMSKIP_WEB_SHOW_MIXERLINKS')
			,'changeIntro' => string('PLUGIN_CUSTOMSKIP_WEB_SHOW_MIXERLINKS')
			,'options' => {
					 '1' => string('ON')
					,'0' => string('OFF')
				}
			,'currentValue' => sub { return Slim::Utils::Prefs::get("plugin_customskip_web_show_mixerlinks"); }
		},
	plugin_customskip_enable_mixerfunction => {
			'validate'     => \&validateTrueFalseWrapper
			,'PrefChoose'  => string('PLUGIN_CUSTOMSKIP_ENABLE_MIXERFUNCTION')
			,'changeIntro' => string('PLUGIN_CUSTOMSKIP_ENABLE_MIXERFUNCTION')
			,'options' => {
					 '1' => string('ON')
					,'0' => string('OFF')
				}
			,'currentValue' => sub { return Slim::Utils::Prefs::get("plugin_customskip_enable_mixerfunction"); }
		},
	plugin_customskip_directory => {
			'validate' => \&validateIsDirWrapper
			,'PrefChoose' => string('PLUGIN_CUSTOMSKIP_DIRECTORY')
			,'changeIntro' => string('PLUGIN_CUSTOMSKIP_DIRECTORY')
			,'PrefSize' => 'large'
			,'currentValue' => sub { return Slim::Utils::Prefs::get("plugin_customskip_directory"); }
		},
	);
	return (\%setupGroup,\%setupPrefs);
}

sub validateIntWrapper {
	my $arg = shift;
	if ($::VERSION ge '6.5') {
		return Slim::Utils::Validate::isInt($arg);
	}else {
		return Slim::Web::Setup::validateInt($arg);
	}
}

sub validateTrueFalseWrapper {
	my $arg = shift;
	if ($::VERSION ge '6.5') {
		return Slim::Utils::Validate::trueFalse($arg);
	}else {
		return Slim::Web::Setup::validateTrueFalse($arg);
	}
}

sub validateAcceptAllWrapper {
	my $arg = shift;
	if ($::VERSION ge '6.5') {
		return Slim::Utils::Validate::acceptAll($arg);
	}else {
		return Slim::Web::Setup::validateAcceptAll($arg);
	}
}

sub validateIsDirWrapper {
	my $arg = shift;
	if ($::VERSION ge '6.5') {
		return Slim::Utils::Validate::isDir($arg);
	}else {
		return Slim::Web::Setup::validateIsDir($arg);
	}
}

sub fisher_yates_shuffle {
    my $myarray = shift;  
    my $i = @$myarray;
    if(scalar(@$myarray)>1) {
	    while (--$i) {
	        my $j = int rand ($i+1);
	        @$myarray[$i,$j] = @$myarray[$j,$i];
	    }
    }
}

sub validateIntOrEmpty {
	my $arg = shift;
	if(!$arg || $arg eq '' || $arg =~ /^\d+$/) {
		return $arg;
	}
	return undef;
}

sub getCurrentDBH {
	if ($::VERSION ge '6.5') {
		return Slim::Schema->storage->dbh();
	}else {
		return Slim::Music::Info::getCurrentDataStore()->dbh();
	}
}

sub getCurrentDS {
	if ($::VERSION ge '6.5') {
		return 'Slim::Schema';
	}else {
		return Slim::Music::Info::getCurrentDataStore();
	}
}

sub objectForId {
	my $type = shift;
	my $id = shift;
	if ($::VERSION ge '6.5') {
		if($type eq 'artist') {
			$type = 'Contributor';
		}elsif($type eq 'album') {
			$type = 'Album';
		}elsif($type eq 'genre') {
			$type = 'Genre';
		}elsif($type eq 'track') {
			$type = 'Track';
		}elsif($type eq 'playlist') {
			$type = 'Playlist';
		}elsif($type eq 'year') {
			$type = 'Year';
		}
		return Slim::Schema->resultset($type)->find($id);
	}else {
		if($type eq 'playlist') {
			$type = 'track';
		}
		return getCurrentDS()->objectForId($type,$id);
	}
}

sub objectForUrl {
	my $url = shift;
	return Slim::Schema->objectForUrl({
		'url' => $url
	});
}

sub getLinkAttribute {
	my $attr = shift;
	if ($::VERSION ge '6.5') {
		if($attr eq 'artist') {
			$attr = 'contributor';
		}
		return $attr.'.id';
	}
	return $attr;
}

sub commit {
	my $dbh = shift;
	if (!$dbh->{'AutoCommit'}) {
		$dbh->commit();
	}
}

sub rollback {
	my $dbh = shift;
	if (!$dbh->{'AutoCommit'}) {
		$dbh->rollback();
	}
}

# other people call us externally.
*escape   = \&URI::Escape::uri_escape_utf8;

# don't use the external one because it doesn't know about the difference
# between a param and not...
#*unescape = \&URI::Escape::unescape;
sub unescape {
        my $in      = shift;
        my $isParam = shift;

        $in =~ s/\+/ /g if $isParam;
        $in =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/eg;

        return $in;
}

# A wrapper to allow us to uniformly turn on & off debug messages
sub debugMsg
{
	my $message = join '','CustomSkip: ',@_;
	msg ($message) if (Slim::Utils::Prefs::get("plugin_customskip_showmessages"));
}

sub strings {
	return <<EOF;
CUSTOMSKIP
	EN	Custom Skip

PLUGIN_CUSTOMSKIP
	EN	Custom Skip

PLUGIN_CUSTOMSKIP_SETUP_GROUP
	EN	Custom Skip

PLUGIN_CUSTOMSKIP_SETUP_GROUP_DESC
	EN	Custom Filter is a plugin which makes it easy to define filters on tracks that shouldnt be played

PLUGIN_CUSTOMSKIP_SHOW_MESSAGES
	EN	Show debug messages

PLUGIN_CUSTOMSKIP_GLOBAL_SKIPPING
	EN	Enable filtering on all playlists (Off = only on Dynamic Playlists)

SETUP_PLUGIN_CUSTOMSKIP_SHOWMESSAGES
	EN	Debugging

SETUP_PLUGIN_CUSTOMSKIP_GLOBAL_SKIPPING
	EN	Enable filtering on all playlists

PLUGIN_CUSTOMSKIP_DIRECTORY
	EN	Filter directory

SETUP_PLUGIN_CUSTOMSKIP_DIRECTORY
	EN	Filter directory

PLUGIN_CUSTOMSKIP_CHOOSE_BELOW
	EN	Choose a filter set for skipping music:

PLUGIN_CUSTOMSKIP_NEW_FILTER
	EN	Create new filter set

PLUGIN_CUSTOMSKIP_NEW_FILTER_TITLE
	EN	Enter attributes for new filter set

PLUGIN_CUSTOMSKIP_EDIT_FILTER_NAME
	EN	Filter Set Name

PLUGIN_CUSTOMSKIP_EDIT_FILTER_FILE_NAME
	EN	File name

PLUGIN_CUSTOMSKIP_NEW_FILTER_TYPES_TITLE
	EN	Select type of filter item to add to filter set

PLUGIN_CUSTOMSKIP_EDIT_FILTER_PARAMETERS_TITLE
	EN	Enter filter item parameters

PLUGIN_CUSTOMSKIP_DELETE_FILTER
	EN	Delete

PLUGIN_CUSTOMSKIP_DELETE_FILTER_QUESTION
	EN	Are you sure you want to delete this filter set ?

PLUGIN_CUSTOMSKIP_EDIT_FILTER
	EN	Edit

PLUGIN_CUSTOMSKIP_CHOOSE_FILTERITEM_BELOW
	EN	Choose a filter item to edit or create a new one

PLUGIN_CUSTOMSKIP_NEW_FILTERITEM
	EN	Create new filter item

PLUGIN_CUSTOMSKIP_DELETE_FILTERITEM
	EN	Delete

PLUGIN_CUSTOMSKIP_DELETE_FILTERITEM_QUESTION
	EN	Are you sure you want to delete this filter item ?

PLUGIN_CUSTOMSKIP_EDIT_FILTERITEM
	EN	Edit

PLUGIN_CUSTOMSKIP_ACTIVE
	EN	Active filter set

PLUGIN_CUSTOMSKIP_ACTIVATING_FILTER
	EN	Activating 

PLUGIN_CUSTOMSKIP_DISABLE_FILTER
	EN	Turn off filtering

PLUGIN_CUSTOMSKIP_DISABLING_FILTER
	EN	Filtering turned off

PLUGIN_CUSTOMSKIP_WEB_SHOW_MIXERLINKS
	EN	Show Custom Skip button in browse pages. May require slimserver restart.

PLUGIN_CUSTOMSKIP_ENABLE_MIXERFUNCTION
	EN	Enable Custom Skip play+hold action. May require slimserver restart.

SETUP_PLUGIN_CUSTOMSKIP_WEB_SHOW_MIXERLINKS
	EN	Buttons in browse pages

SETUP_PLUGIN_CUSTOMSKIP_ENABLE_MIXERFUNCTION
	EN	Play+Hold mixer action

PLUGIN_CUSTOMSKIP_SELECT_FILTER_TYPE
	EN	Select type of skip filter

PLUGIN_CUSTOMSKIP_MIX_FILTER_SUCCESS
	EN	Updated filter set

PLUGIN_CUSTOMSKIP_MIX_FILTER_FAILURE
	EN	Update failed

PLUGIN_CUSTOMSKIP_SELECT_MIX_ITEM
	EN	Select item to filter on

PLUGIN_CUSTOMSKIP_SELECT_FILTER_SET
	EN	Select this filter set for skipping music
EOF

}

1;

__END__
