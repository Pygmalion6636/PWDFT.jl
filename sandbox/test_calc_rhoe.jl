using PWDFT

function test_main()

    atoms = init_atoms_xyz_string("""
    1

    H  0.0  0.0  0.0
    """)
    atoms.LatVecs = gen_lattice_cubic(16.0)
    
    ecutwfc_Ry = 30.0
    kpoints = KPoints( atoms, [2,2,2], [0,0,0], verbose=true )
    pw = PWGrid( ecutwfc_Ry*0.5, atoms.LatVecs, kpoints=kpoints )
    Ngw = pw.gvecw.Ngw
    Nkpt = pw.gvecw.kpoints.Nkpt

    Nstates = 4
    Focc = 2.0*ones(Nstates,Nkpt)

    psik = Array{Array{Complex128,2},1}(Nkpt)
    for ik = 1:Nkpt
        psi = rand( Complex128, Ngw[ik], Nstates )
        psik[ik] = ortho_gram_schmidt(psi)  # orthogonalize in G-space
    end

    rhoe = calc_rhoe( pw, Focc, psik )
    dVol = pw.Ω/prod(pw.Ns)
    @printf("Integrated rhoe = %18.10f\n", sum(rhoe)*dVol)

    rhoeG_full = R_to_G( pw, rhoe )
    println("sum rhoeG_full = ", sum(rhoeG_full))

    Ng = pw.gvec.Ng
    rhoeG = zeros( Complex128, Ng )
    rhoeG = rhoeG_full[pw.gvec.idx_g2r]
    println("sum rhoeG = ", sum(rhoeG))
end

test_main()
