
using SpecialFunctions: erfc

"""
 Ewaldsum fortran 90 code
   4/23/01  NAWH
!   Input :   T1x  T1y   T1z    (Cartesian components of lattice vectors)
!         :   T2x  T2y   T2z
!         :   T3x  T3y   T3z
!         :   Natomss             (Number of ions in unit cell)
!         :   q(i), tau(1:3,i), i=1,Natoms  (charge and fractional position
!                                             of ions)
!             Note:  ion positions = tau(1,i)*T1 + tau(2,i)*T2 + tau(3,i)*T3
!         :   eps    (error tolerance)
"""
function calc_E_NN_new( LatVecs::Array{Float64,2}, atoms::Atoms, Zvals::Array{Float64,1} )

#  REAL(8) :: pi,eps, t1[3], t2[3], t3[3], g1(3),g2(3),g3(3),volcry, arg,x,gexp
#  REAL(8) :: eta, totalcharge, g1m, g2m, g3m, t1m, t2m, t3m,gcut, tmax ,ebsl,seta
#  REAL(8) :: tpi,glast2, con, con2 , cccc , ewald , v(3), w(3), rmag2 , prod
#  INTEGER  :: Natoms, i, j, k, ng, nt , mmm1, mmm2, mmm3 , a , b
#  REAL(8), ALLOCATABLE :: q(:), tau(:,:)

    t1 = LatVecs[1,:]
    t2 = LatVecs[2,:]
    t3 = LatVecs[3,:]

#  Write(6,*) ' Enter T1x, T1y, T1z in bohr units'
#  Read(5,*) t1[1],t1[2],t1[3]
#  Write(6,*) ' Enter T2x, T2y, T2z in bohr units'
#  Read(5,*) t2[1],t2[2],t2[3]
#  Write(6,*) ' Enter T3x, T3y, T3z in bohr units'
#  Read(5,*) t3[1],t3[2],t3[3]
  
    volcry = t1[1]*(t2[2]*t3[3]-t2[3]*t3[2]) +
             t1[2]*(t2[3]*t3[1]-t2[1]*t3[3]) +
             t1[3]*(t2[1]*t3[2]-t2[2]*t3[1])

    g1 = zeros(Float64,3)
    g2 = zeros(Float64,3)
    g3 = zeros(Float64,3)

    g1[1] = 2.0*pi * (t2[2]*t3[3]-t2[3]*t3[2])/volcry
    g1[2] = 2.0*pi * (t2[3]*t3[1]-t2[1]*t3[3])/volcry
    g1[3] = 2.0*pi * (t2[1]*t3[2]-t2[2]*t3[1])/volcry
    g2[1] = 2.0*pi * (t3[2]*t1[3]-t3[3]*t1[2])/volcry
    g2[2] = 2.0*pi * (t3[3]*t1[1]-t3[1]*t1[3])/volcry
    g2[3] = 2.0*pi * (t3[1]*t1[2]-t3[2]*t1[1])/volcry
    g3[1] = 2.0*pi * (t1[2]*t2[3]-t1[3]*t2[2])/volcry
    g3[2] = 2.0*pi * (t1[3]*t2[1]-t1[1]*t2[3])/volcry
    g3[3] = 2.0*pi * (t1[1]*t2[2]-t1[2]*t2[1])/volcry
  
    volcry = abs(volcry)

    t1m = sqrt(dot(t1,t1))
    t2m = sqrt(dot(t2,t2))
    t3m = sqrt(dot(t3,t3))
    g1m = sqrt(dot(g1,g1))
    g2m = sqrt(dot(g2,g2))
    g3m = sqrt(dot(g3,g3))

    Natoms = atoms.Natoms
    atm2species = atoms.atm2species
    
    #Allocate(q(Natoms),tau(3,Natoms))

    # scaled atomic positions
    tau = inv(LatVecs)*atoms.positions

    #do i=1,Natoms
    #    read(5,*) q(i),tau(1,i),tau(2,i),tau(3,i)
    #enddo

    const gcut = 2.0
    const ebsl = 1e-8

    tpi = 2.0*pi
    con = volcry/(4.0*pi)
    con2 = (4.0*pi)/volcry
    glast2 = gcut*gcut
    gexp = -log(ebsl)
    eta = glast2/gexp

    @printf("eta = %18.10f\n" , eta)
    cccc = sqrt(eta/pi)

    x = 0.0
    totalcharge = 0.0
    for ia = 1:Natoms
        isp = atm2species[ia]
        x = x + Zvals[isp]^2
        totalcharge = totalcharge + Zvals[isp]
    end

    @printf("Total charge = %18.10f\n", totalcharge)

    ewald = -cccc*x - 4.0*pi*(totalcharge^2)/(volcry*eta)

    tmax = sqrt(2.0*gexp/eta)
    seta = sqrt(eta)/2.0

    mmm1 = round(Int64, tmax/t1m + 1.5)
    mmm2 = round(Int64, tmax/t2m + 1.5)
    mmm3 = round(Int64, tmax/t3m + 1.5)
    @printf("Lattice summation indices %d %d %d\n", mmm1, mmm2, mmm3)

    v = zeros(Float64,3)
    w = zeros(Float64,3)

    for ia = 1:Natoms
    for ja = 1:Natoms
        v[:] = ( tau[1,ia] - tau[1,ja] )*t1[:] +
               ( tau[2,ia] - tau[2,ja] )*t2[:] +
               ( tau[3,ia] - tau[3,ja] )*t3[:]
        isp = atm2species[ia]
        jsp = atm2species[ja]
        prd = Zvals[isp]*Zvals[jsp]
        for i = -mmm1:mmm1
        for j = -mmm2:mmm2
        for k = -mmm3:mmm3
            if (ia != ja) || ( (abs(i) + abs(j) + abs(k)) != 0 )
                w[:] = v[:] + i*t1 + j*t2 + k*t3
                rmag2 = sqrt(dot(w,w))
                arg = rmag2*seta 
                ewald = ewald + prd*erfc(arg)/rmag2
            end
        end
        end
        end
    end
    end

    mmm1 = round(gcut/g1m + 1.5)
    mmm2 = round(gcut/g2m + 1.5)
    mmm3 = round(gcut/g3m + 1.5)
      
    @printf("Reciprocal lattice summation indices: %d %d %d\n", mmm1, mmm2, mmm3)
    for i = -mmm1:mmm1
    for j = -mmm2:mmm2
    for k = -mmm3:mmm3
        if ( abs(i) + abs(j) + abs(k) ) != 0
            w[:] = i*g1[:] + j*g2[:] + k*g3[:]
            rmag2 = dot(w,w)
            x = con2*exp(-rmag2/eta)/rmag2
            for ia = 1:Natoms
            for ja = 1:Natoms
                v[:] = tau[:,ia] - tau[:,ja]
                isp = atm2species[ia]
                jsp = atm2species[ja]
                prd = Zvals[isp]*Zvals[jsp]
                arg = tpi*( i*v[1] + j*v[2] + k*v[3] )
                ewald = ewald + x*prd*cos(arg)
            end # ja
            end # ia
        end # if
    end
    end
    end

    @printf("Ewald energy %18.10f Ha\n", ewald*0.5)

    return ewald*0.5
end