-- Requête SQL pour investiguer l'incohérence des noms patients
-- À exécuter dans la base de données WARMS

-- 1. Vérifier tous les patients avec leurs informations
SELECT 
    p.id,
    p.prenom,
    p.nom,
    p.date_naissance,
    p.telephone,
    p.email,
    p.actif,
    u.username,
    u.first_name as user_first_name,
    u.last_name as user_last_name,
    u.email as user_email,
    d.numero_dossier
FROM patients_patient p
LEFT JOIN personnel_utilisateur u ON p.user_id = u.id
LEFT JOIN patients_dossierpatient d ON p.id = d.patient_id
ORDER BY p.id;

-- 2. Vérifier les patients avec des noms différents entre patient et user
SELECT 
    p.id,
    p.prenom as patient_prenom,
    p.nom as patient_nom,
    u.first_name as user_first_name,
    u.last_name as user_last_name,
    u.username,
    CASE 
        WHEN p.prenom != u.first_name OR p.nom != u.last_name THEN 'INCOHERENCE'
        ELSE 'OK'
    END as status
FROM patients_patient p
INNER JOIN personnel_utilisateur u ON p.user_id = u.id
WHERE p.prenom != u.first_name OR p.nom != u.last_name
ORDER BY p.id;

-- 3. Compter le nombre total de patients
SELECT COUNT(*) as total_patients FROM patients_patient WHERE actif = true;

-- 4. Vérifier les patients sans compte utilisateur
SELECT 
    p.id,
    p.prenom,
    p.nom,
    p.telephone,
    p.email,
    'NO_USER_ACCOUNT' as status
FROM patients_patient p
WHERE p.user_id IS NULL AND p.actif = true
ORDER BY p.id;
