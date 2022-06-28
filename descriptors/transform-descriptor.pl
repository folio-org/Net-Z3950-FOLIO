version=`perl -I lib -MNet::Z3950::FOLIO -e '$x = $Net::Z3950::FOLIO::VERSION; $x =~ s/.//; print $x'`
cat ${@+"$@"} | perl -npe 's/\${version}/'"$version"'/g; s/\${artifactId}/mod-z3950/g;'
