package EPrints::Plugin::Export::IIIFManifest;

use EPrints::Plugin::Export::TextFile;
use Image::ExifTool;
use JSON;

@ISA = ( "EPrints::Plugin::Export::TextFile" );

use strict;

sub new
{
	my( $class, %opts ) = @_;

	my( $self ) = $class->SUPER::new( %opts );

	$self->{name}     = 'IIIF Manifest';
	$self->{accept}   = [ 'dataobj/*' ];
	$self->{visible}  = 'all';
	$self->{suffix}   = '.json';
	$self->{mimetype} = 'application/json; charset=utf-8';

	return $self;
}

sub output_dataobj
{
	my( $plugin, $eprint ) = @_;

	my $repo     = $plugin->repository;
	my $exiftool = new Image::ExifTool;
	my $id       = $eprint->uri;
	$id          =~ s|id/eprint/|cgi/iiif?eprintid=|;

	my $data = {
		'@context'  => 'http://iiif.io/api/presentation/3/context.json',
		'id'        => $id,
		'type'      => 'Manifest',
		'label'     => { 'en' => [ $eprint->value( 'title' ) ] },
		'summary'   => { 'en' => [ $eprint->value( 'abstract' ) ] },
		'items'     => [],
		'metadata'  => [
			{
				'label' => { 'en' => [ 'Collection' ] },
				'value' => { 'en' => [ $eprint->value( 'collection' ) ] },
			},
			{
				'label' => { 'en' => [ 'DateRange' ] },
				'value' => { 'en' => [ $eprint->value( 'date_range' ) ] },
			},
			{
				'label' => { 'en' => [ 'EMuID' ] },
				'value' => { 'en' => [ $eprint->value( 'emu_id' ) ] },
			},
			{
				'label' => { 'en' => [ 'EPrintID' ] },
				'value' => { 'en' => [ $eprint->value( 'eprintid' ) ] },
			},
			{
				'label' => { 'en' => [ 'PhysicalIdentifier' ] },
				'value' => { 'en' => [ $eprint->value( 'physical_identifier' ) ] },
			}
		],
	};

	my @docs = $eprint->get_all_documents;

	my @canvases;
	for( my $i = 0; $i < scalar @docs; $i++ )
	{
		my $doc = $docs[$i];
		my @rels;
		my $relation;
		my $filetype;
		my $fileobj  = $doc->stored_file( $doc->get_main );
		my $filepath = '' . $fileobj->get_local_copy;
		my $fileinfo = $exiftool->ExtractInfo( $filepath, { 'FastScan' => 5 } );
		my $body = {
			'id'     => $doc->get_url(),
			'format' => $doc->get_value( 'mime_type' )
		};
		if ( $doc->get_value( 'format' ) eq 'audio' ) {
			$relation           = 'isaudio_mp3ThumbnailVersionOf';
			$filetype           = 'Sound';
			$body->{'type'}     = 'Sound';
			my $mp3info         = $exiftool->GetInfo( 'Duration#' );
			$body->{'duration'} = sprintf( '%d', $mp3info->{'Duration #'} );
		} elsif ($doc->get_value( 'format' ) eq 'image' ) {
			$relation         = 'islightboxThumbnailVersionOf';
			$filetype         = 'Image';
			$body->{'type'}   = 'Image';
			my $imginfo       = $exiftool->GetInfo('ImageWidth', 'ImageHeight');
			$body->{'width'}  = $imginfo->{'ImageWidth'};
			$body->{'height'} = $imginfo->{'ImageHeight'};
		}


		my $related = $doc->search_related( $relation );
		if ( $related->count > 0 )
		{
			$related->map( sub {
				my( $session, $dataset, $eprintdoc, $rels ) = @_;
				my $thumb = {
					'id'     => $eprintdoc->get_url(),
					'type'   => $filetype,
					'format' => $eprintdoc->value( 'mime_type' ),
				};
				if ( $filetype eq 'Image' )
				{
					my $relfileobj = $eprintdoc->stored_file( $eprintdoc->get_main );
					my $relfilepath = '' . $relfileobj->get_local_copy;
					my $relinfo = $exiftool->ExtractInfo( $relfilepath, { 'FastScan' => 5 } );
					my $relimginfo = $exiftool->GetInfo('ImageWidth', 'ImageHeight');
					$thumb->{'width'} = $relimginfo->{'ImageWidth'};
					$thumb->{'height'} = $relimginfo->{'ImageHeight'};
				}
				if ( $filetype eq 'Sound' )
				{
					$thumb->{'duration'} = $body->{'duration'};
				}
				push @$rels, $thumb;

			}, \@rels );
		}
		push @canvases, {
			'id'    => $doc->uri,
			'type'  => 'Canvas',
			'label' => { 'en' => [ $doc->get_value( 'formatdesc' ) ] },
			'items' => [
				{
					'id'        => $doc->uri,
					'type'      => 'Annotation',
					'body'      => $body,
					'thumbnail' => \@rels
				}
			]
		};
	}

	$data->{items} = \@canvases;

	return JSON->new->pretty(1)->encode( $data );
}

1;
