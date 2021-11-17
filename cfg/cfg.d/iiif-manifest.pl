$c->{plugins}{'Export::IIIFManifest'}{params}{disable} = 0;
$c->{on_generate_thumbnails} = sub
{
    my ($session, $doc) = @_;
    my $eprint = $doc->parent;
    my $dir  = $session->get_repository->config( 'variables_path' ) . '/iiif-manifests';
    my $id   = $eprint->value( 'eprintid' );
    my $file = "$dir/$id.json";
    if ( -e $file )
    {
        unlink $file;
    }
}