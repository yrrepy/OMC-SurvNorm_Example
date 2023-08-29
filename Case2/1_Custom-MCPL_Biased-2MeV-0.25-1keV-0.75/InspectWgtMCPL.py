from enum import Enum
import mcpl
import os
import numpy as np


mcplfile = mcpl.MCPLFile("surface_source.mixedBiased.mcpl")

class ParticleType(Enum):
    neutron = 0              #  neutron (2112 in MCPL)
    photon  = 1              #  photon  (22   in MCPL)


totweight  =0
ncount     =0
ntotweight =0
pcount     =0
ptotweight =0

MCparticles = []
for p in mcplfile.particles:
    totweight += p.weight         # Sum Total Weight

    pp = p.pdgcode
    if pp == 2112: 
        pp = ParticleType.neutron
        ncount     += 1           # Count Neutrons
        ntotweight += p.weight    # Sum   Neutron Weight

print("  ");
print("  ");
print("_____________________________________________");
print("Total Particle Count = ",ncount+pcount);
print("Total       Weight   = ",totweight);
print("Total Avg.  Weight   = ",totweight/(ncount+pcount));
print("-------------------------");
print("Neutron       Count  = ",ncount);
print("Neutron Total Weight = ",ntotweight);
print("Neutron Avg.  Weight = ",ntotweight/ncount);
print("-------------------------");
print("  ");
print("  ");