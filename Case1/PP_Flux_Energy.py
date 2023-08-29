import glob
import matplotlib.pyplot as plt
import math
import numpy  as np
import pandas as pd
import openmc

print(" ");
print(" ");
print(" ");
print(" ");
print(" ");
print("Start OpenMC Lattice Tally Post-Processing Script");
print(" -----------------------------------------------");
print(" ");
print(" ");
# We do not know how many batches were needed to satisfy the 
# tally trigger(s), so find the statepoint file(s)
statepoints = glob.glob('statepoint.50.h5')

# Load the last statepoint file
sp = openmc.StatePoint(statepoints[-1]);


# Total time elapsed [seconds]  (OpenMC total time of simulation)
trun = sp.runtime['simulation']/60; # Convert from seconds to minutes
print("Total Simulation Time: ",trun," minutes");


# Creating Empty Lists and DataFrames
df        = pd.DataFrame();  
FluxTally = sp.get_tally(id=2);
df        = FluxTally.get_pandas_dataframe()   ;

# Add Relative Errors and Figure of Merit to DataFrame  
df= df.assign(RErr =     df['std. dev.']/df['mean']);            
df= df.assign(FOM  = 1/((df['RErr'] * df['RErr'])*trun));  

print("");
print("");

# Creating Empty Lists and DataFrames
dfH        = pd.DataFrame();  
HeatTally = sp.get_tally(id=3);
dfH        = HeatTally.get_pandas_dataframe()   ;

# Add Relative Errors and Figure of Merit to DataFrame  
dfH= dfH.assign(RErr =     dfH['std. dev.']/dfH['mean']);            
dfH= dfH.assign(FOM  = 1/((dfH['RErr'] * dfH['RErr'])*trun));  


# Creating Empty Lists and DataFrames
df1        = pd.DataFrame();  
FluxTally1 = sp.get_tally(id=4);
df1        = FluxTally1.get_pandas_dataframe()   ;

# Add Relative Errors and Figure of Merit to DataFrame  
df1= df1.assign(RErr =     df1['std. dev.']/df1['mean']);            
df1= df1.assign(FOM  = 1/((df1['RErr'] * df1['RErr'])*trun));  

print("");
print("");

# Creating Empty Lists and DataFrames
dfH1        = pd.DataFrame();  
HeatTally1 = sp.get_tally(id=5);
dfH1        = HeatTally1.get_pandas_dataframe()   ;

# Add Relative Errors and Figure of Merit to DataFrame  
dfH1= dfH1.assign(RErr =     dfH1['std. dev.']/dfH1['mean']);            
dfH1= dfH1.assign(FOM  = 1/((dfH1['RErr'] * dfH1['RErr'])*trun));  



# print("");
# print("");
# print(df.tail(6));
# 
# print("");
# print("");
# print(dfH.tail(6));


print("");
print("");
print(df1.tail(6));

print("");
print("");
print(dfH1.tail(6));
 
 
print("");
print("");
print (sp.get_tally(id=9991).get_pandas_dataframe() )


print("");
print("");
# print(trun, df.loc[4,'mean'],df.loc[4,'RErr'],df.loc[4,'FOM'],df.loc[5,'mean'],df.loc[5,'RErr'],df.loc[5,'FOM'],sp.get_tally(id=9991).get_pandas_dataframe().loc[0,'mean']);
print("");
print("");


# Close the statepoint file as a matter of best practice
sp.close()