#include "mcpl.h"
#include <stdio.h>
#include <stdlib.h>

int main(int argc,char**argv) {


  if (argc!=6) {
    printf("Please supply input, output filenames, Zmin, Zmax, X-Translation\n");
    return 1;
  }

  const char * infilename  = argv[1];
  const char * outfilename = argv[2];
  const double        Zmin = strtol(argv[3], 0, 0);
  const double        Zmax = strtol(argv[4], 0, 0);
  const double      TransX = strtol(argv[5], 0, 0);

  // Initialisation, open existing file and create output file handle. Transfer
  // all meta-data from existing file, and add an extra comment in the output
  // file to document the process:

  mcpl_file_t fi = mcpl_open_file(infilename);
  mcpl_outfile_t fo = mcpl_create_outfile(outfilename);
  mcpl_transfer_metadata(fi, fo);
  mcpl_hdr_add_comment(fo,"Translated Shield Source Points (-120cm,0,0)");
  //mcpl_enable_userflags(fo);

  //Loop over particles from input, only triggering mcpl_add_particle calls for
  //the chosen particles:

  mcpl_particle_t* particle;
  while ( ( particle = mcpl_read(fi) ) ) {
    if ( (particle->position[2] > Zmin) && (particle->position[2] < Zmax) ) {
      particle->position[0]  = particle->position[0] +TransX;                           // translate shield X positions
    }
    //particle->userflags  = 0x00001f48; 
    mcpl_add_particle(fo,particle);
    //Note that a guaranteed non-lossy alternative to mcpl_add_particle(fo,particle)
    //would be mcpl_transfer_last_read_particle(fi,fo) which can work directly on
    //the serialised on-disk particle data.
  }

  //Close up files:
  mcpl_close_outfile(fo);
  mcpl_close_file(fi);
}