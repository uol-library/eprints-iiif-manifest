# enable the plugin
$c->{plugins}{'Export::IIIFManifest'}{params}{disable} = 0;

# on_generate_thumbnails iscalled whenever thumbnails are regenerated
# for a given document. First save a reference to the original
if ( defined $c->{on_generate_thumbnails} )
{
    $c->{iiif_on_generate_thumbnails} = \&{$c->{on_generate_thumbnails}};
}

# defines a subroutine to remove a cached copy of the manifest when
# thumbnails are regenerated
$c->{on_generate_thumbnails} = sub
{
    # call the original subroutine if it exists
    if ( defined $c->{iiif_on_generate_thumbnails} ) {
        $c->{iiif_on_generate_thumbnails}();
    }
    my ($session, $doc) = @_;
    # get the eprint (this is called in the document scope)
    my $eprint = $doc->parent;
    # get the path to the cached manifest
    my $dir  = $session->get_repository->config( 'variables_path' ) . '/iiif-manifests';
    my $id   = $eprint->value( 'eprintid' );
    my $file = "$dir/$id.json";
    # if the file exists, remove it
    if ( -e $file )
    {
        unlink $file;
    }
}