import np2mcpl
import numpy as np
from numpy import random
import mcpl
import os
import glob
# import openmc
# import hashlib
# import pathlib as pl
# import h5py
# from enum import Enum


# class ParticleType(Enum):
#     neutron = 0              #  neutron (2112 in MCPL)
#     photon  = 1              #  photon  (22   in MCPL)


mcplfile = mcpl.MCPLFile("../1_Custom-MCPL_Biased-2MeV-0.25-1keV-0.75/surface_source.mcpl")

MCPLArray = np.empty((0,10))
for p in mcplfile.particles:
     pp     = p.pdgcode
     x      = 0
     y      = 0
     z      = 0
     ux     = p.ux
     uy     = p.uy
     uz     = p.uz                          
     t      = 0
     if pp==2112:                           # Neutrons
         weight = 0.25                      # adjust neutron weight  
         energy = 2.0 
     MCp = (pp,x,y,z,ux,uy,uz,t,energy,weight) 
#    print(MCp)

     MCPLArray=np.r_[MCPLArray,[MCp]]

     
# print(MCPLArray);
# print();


# 
# 
np2mcpl.save(f'surface_source.2MeV-0.25.mcpl',MCPLArray)


MCPLArray2 = np.empty((0,10))
for p in mcplfile.particles:
     pp     = p.pdgcode
     x      = 0.00
     y      = 0.00
     z      = 0.00
     ux     = p.ux
     uy     = p.uy
     uz     = p.uz                         
     t      = 0.00
     if pp==2112:                           # Neutrons
         weight = 0.75                      # adjust neutron weight  
         energy = 0.001 
     MCp = (pp,x,y,z,ux,uy,uz,t,energy,weight) 
#    print(MCp)

     MCPLArray2=np.r_[MCPLArray2,[MCp]]

     
# print(MCPLArray);
# print();


# 
# 
np2mcpl.save(f'surface_source.1keV-0.75.mcpl',MCPLArray2)

