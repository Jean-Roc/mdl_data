@ECHO OFF

rem Script DOS récupérant la donnée OCS/RTGE de la MEL pour produire un fond de plan disponible sans connexion
rem le script nécessite seulement un environnement gdal/ogr 3.x, celui disponible avec l'installation qgis suffit
rem #shadowit #onfaitavec #annees90forever

rem Enregistrer l'heure de début
set STARTTIME=%TIME%

mkdir %USERPROFILE%\Documents\SIG\
mkdir %USERPROFILE%\Documents\SIG\temp
mkdir %USERPROFILE%\Documents\SIG\temp\extraction

SET LOCAL_WORKSPACE_PATH=%USERPROFILE%\Documents\SIG\temp
SET SERVER_PATH=\\eureka\commun\equipemt\SIG Data Lille\Donnees\sources_externes

rem paramètres d'extraction des données par les flux WFS du Geoserver de la MEL
SET EXTRACT_OUTPUT_PATH=%LOCAL_WORKSPACE_PATH%\extraction\
SET EXTRACT_OUTPUT_FILENAME=mel_extraction_wfs
rem bbox au format xmin ymin xmax ymax
SET BBOX=694500 7053500 712000 7065000
SET MEL_URL_WFS=https://mel-geoserver.lillemetropole.fr/geoserver/wfs?TYPENAMES=
SET EXTRACT_SETTINGS=-overwrite --config OGR_WFS_PAGE_SIZE 100000 -gt 65536 -makevalid -preserve_fid -a_srs EPSG:2154
SET LAYER_COMMUNES=communes
SET LAYER_ILOT=ilots
SET LAYER_SURFACE=surface
SET LAYER_PONCTUEL=rtge_ponctuels
SET LAYER_LINEAIRE=rtge_lineaires
SET LAYER_VOIES_ADMIN=voies_admin
SET LAYER_VOIES_TRONCONS=voies_troncons

ECHO Etape 1 - recuperation des donnees WFS en cours

ogr2ogr -f GPKG %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_COMMUNES% WFS:%MEL_URL_WFS%Diffusion_Referentiel:MEL_COMMUNE -nlt POLYGON %EXTRACT_SETTINGS% -select CODE_INSEE,NOM,SOURCE_MIL

ogr2ogr -f GPKG %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_ILOT% WFS:%MEL_URL_WFS%Diffusion:V_OCSMEL_CONSULTATION_ILOT -spat %BBOX% -nlt MULTIPOLYGON %EXTRACT_SETTINGS%

ogr2ogr -f GPKG %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_SURFACE% WFS:%MEL_URL_WFS%Diffusion:V_OCSMEL_CONSULTATION -spat %BBOX% -nlt POLYGON %EXTRACT_SETTINGS%

ogr2ogr -f GPKG %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_PONCTUEL% WFS:%MEL_URL_WFS%Diffusion_RTGE:TA_RTGE_POINT_CONSULTATION -spat %BBOX% -nlt POINT %EXTRACT_SETTINGS%

ogr2ogr -f GPKG %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_LINEAIRE% WFS:%MEL_URL_WFS%Diffusion_RTGE:TA_RTGE_LINEAIRE_CONSULTATION -spat %BBOX% -nlt LineString %EXTRACT_SETTINGS%

ogr2ogr -f GPKG %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_VOIES_ADMIN% WFS:%MEL_URL_WFS%Diffusion_RSMT:VOD_CONSULTATION_VOIE_ADMINISTRATIVE -spat %BBOX% -nlt PROMOTE_TO_MULTI %EXTRACT_SETTINGS%
ogr2ogr -f GPKG %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_VOIES_TRONCONS% WFS:%MEL_URL_WFS%Diffusion_RSMT:VOD_CONSULTATION_BASE_VOIE -spat %BBOX% -nlt LineString %EXTRACT_SETTINGS%

REM ogrinfo -sql "CREATE INDEX ON %LAYER_ILOT% USING SURFACE" %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg --config CPL_DEBUG ON

ECHO Etape 1 - recuperation des donnees WFS faite !

REM paramètres de conversion de couches préparées
mkdir %USERPROFILE%\Documents\SIG\temp\conversion
SET CONVERT_OUTPUT_PATH=%LOCAL_WORKSPACE_PATH%\conversion
SET CONVERT_OUTPUT_FILENAME=mel_conversion
SET CONVERT_SETTINGS=-overwrite -gt 65536 -preserve_fid -a_srs EPSG:2154 -update
SET LAYER_ILOT_Z20=ilots_complet_z20
SET LAYER_ILOT_Z13=ilots_z13
SET LAYER_ILOT_Z12=ilots_z12
SET LAYER_SURFACE_Z17=surface_complet_z17
SET LAYER_SURFACE_Z15=surface_z15
SET LAYER_SURFACE_Z13=surface_z13
SET LAYER_PONCTUEL_Z21=rtge_ponctuel_complet_z21
SET LAYER_LINEAIRE_Z21=rtge_lineaire_complet_z21
SET LAYER_LINEAIRE_Z17=rtge_lineaire_z17
SET LAYER_VOIES_ADMIN_Z14=voies_admin_z14
SET LAYER_VOIES_ADMIN_Z17=voies_admin_complet_z17

ECHO Etape 2 - conversion des communes et ilots en cours

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_COMMUNES% %CONVERT_SETTINGS% -sql "SELECT * FROM %LAYER_COMMUNES% WHERE ST_GeometryType(geom) = 'POLYGON'" -nlt POLYGON

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_ILOT_Z20% %CONVERT_SETTINGS% -sql "SELECT * FROM %LAYER_ILOT% WHERE geom IS NOT NULL AND (ST_GeometryType(geom) = 'MULTIPOLYGON' OR ST_GeometryType(geom) = 'POLYGON')" -nlt PROMOTE_TO_MULTI

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_ILOT_Z13% %CONVERT_SETTINGS% -sql "SELECT *, CastToSingle(ST_ExteriorRing(geom)) AS geom FROM %LAYER_ILOT% WHERE SURFACE > 500 AND geom IS NOT NULL AND (ST_GeometryType(geom) = 'MULTIPOLYGON' OR ST_GeometryType(geom) = 'POLYGON')" -nlt POLYGON -simplify 10

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_ILOT_Z12% %CONVERT_SETTINGS% -sql "SELECT *, CastToSingle(ST_ExteriorRing(geom)) AS geom FROM %LAYER_ILOT% WHERE SURFACE > 3000 AND geom IS NOT NULL AND (ST_GeometryType(geom) = 'MULTIPOLYGON' OR ST_GeometryType(geom) = 'POLYGON')" -nlt POLYGON -simplify 20

ECHO Etape 2 - conversion des communes et ilots faite !

rem conversion des surfaces (bâtiments,stations, etc.)
ECHO Etape 3 - conversion des surfaces en cours
ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_SURFACE_Z17% %CONVERT_SETTINGS% -sql "SELECT * FROM %LAYER_SURFACE% WHERE geom IS NOT NULL AND (ST_GeometryType(geom) = 'MULTIPOLYGON' OR ST_GeometryType(geom) = 'POLYGON')"

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_SURFACE_Z15% %CONVERT_SETTINGS% -sql "SELECT *, CastToSingle(ST_ExteriorRing(geom)) AS geom FROM %LAYER_SURFACE% WHERE geom IS NOT NULL AND (ST_GeometryType(geom) = 'MULTIPOLYGON' OR ST_GeometryType(geom) = 'POLYGON') AND SURFACE > 500 AND (IDENTIFIANT_TYPE = 325 OR IDENTIFIANT_TYPE = 830 OR IDENTIFIANT_TYPE = 356 OR IDENTIFIANT_TYPE = 223 OR IDENTIFIANT_TYPE = 831 OR IDENTIFIANT_TYPE = 355 OR IDENTIFIANT_TYPE = 362 OR IDENTIFIANT_TYPE = 363 OR IDENTIFIANT_TYPE = 364 OR IDENTIFIANT_TYPE = 206 OR IDENTIFIANT_TYPE = 867 OR IDENTIFIANT_TYPE = 834 OR IDENTIFIANT_TYPE = 364)" -nlt POLYGON -simplify 2

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nln %LAYER_SURFACE_Z13% %CONVERT_SETTINGS% -sql "SELECT *, CastToSingle(ST_ExteriorRing(geom)) AS geom FROM %LAYER_SURFACE% WHERE geom IS NOT NULL AND (ST_GeometryType(geom) = 'MULTIPOLYGON' OR ST_GeometryType(geom) = 'POLYGON') AND SURFACE > 3000 AND (IDENTIFIANT_TYPE = 325 OR IDENTIFIANT_TYPE = 830 OR IDENTIFIANT_TYPE = 356 OR IDENTIFIANT_TYPE = 223 OR IDENTIFIANT_TYPE = 831 OR IDENTIFIANT_TYPE = 355 OR IDENTIFIANT_TYPE = 362 OR IDENTIFIANT_TYPE = 363)" -nlt POLYGON -simplify 4

ECHO Etape 3 - conversion des surfaces - faite !

ECHO Etape 4 - conversion des ponctuels et lineaires du RTGE en cours

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg -nlt POINT -sql "SELECT * FROM %LAYER_PONCTUEL% WHERE geom IS NOT NULL" -nln %LAYER_PONCTUEL_Z21% %CONVERT_SETTINGS%

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg %CONVERT_SETTINGS% -nlt LINESTRING -sql "SELECT * FROM %LAYER_LINEAIRE% WHERE geom IS NOT NULL AND ST_GeometryType(geom) != 'POINT'" -nln %LAYER_LINEAIRE_Z21% 

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg %CONVERT_SETTINGS% -sql "SELECT * FROM %LAYER_LINEAIRE% WHERE geom IS NOT NULL AND IDENTIFIANT_TYPE = 197 AND ST_GeometryType(geom) != 'POINT' AND ST_Length(geom) > 5" -nln %LAYER_LINEAIRE_Z17%

ECHO Etape 4 - conversion des ponctuels et lineaires du RTGE - faite !

ECHO Etape 5 - conversion des elements de voirie en cours

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg %CONVERT_SETTINGS% -nlt PROMOTE_TO_MULTI -sql "SELECT * FROM %LAYER_VOIES_ADMIN% WHERE geom IS NOT NULL AND ST_GeometryType(geom) != 'POINT' AND "HIERARCHIE" = 'voie principale' AND TYPE_VOIE NOT IN ('Passage%', 'Chemin%', 'Résidence', 'Courée', 'Pavillon', 'Allée') AND ST_Length(geom) > 100" -nln %LAYER_VOIES_ADMIN_Z14%

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg %CONVERT_SETTINGS% -nlt PROMOTE_TO_MULTI -sql "SELECT * FROM %LAYER_VOIES_ADMIN% WHERE geom IS NOT NULL AND ST_GeometryType(geom) != 'POINT'" -nln %LAYER_VOIES_ADMIN_Z17%

ogr2ogr -if GPKG -f GPKG %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg %EXTRACT_OUTPUT_PATH%\%EXTRACT_OUTPUT_FILENAME%.gpkg %CONVERT_SETTINGS% -sql "SELECT * FROM %LAYER_VOIES_TRONCONS% WHERE geom IS NOT NULL AND ST_GeometryType(geom) != 'POINT'" -nlt LINESTRING -nln %LAYER_VOIES_TRONCONS%

ECHO Etape 5 - conversion des elements de voirie faite !

ECHO Etape 6 - conversion en Flatgeobuf en cours

rem sauvegarde en Flatgeobuf
mkdir %LOCAL_WORKSPACE_PATH%\conversion\fgb
SET CONVERT_FGB_OUTPUT_PATH=%LOCAL_WORKSPACE_PATH%\conversion\fgb

ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_COMMUNES%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_COMMUNES%" -nln %LAYER_COMMUNES% -dsco TITLE=%LAYER_COMMUNES%

ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_ILOT_Z12%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_ILOT_Z12%" -dsco TITLE=%LAYER_ILOT_Z12% -nln %LAYER_ILOT_Z12%"
ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_ILOT_Z13%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_ILOT_Z13%" -dsco TITLE=%LAYER_ILOT_Z13% -nln %LAYER_ILOT_Z13%
ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_ILOT_Z20%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_ILOT_Z20%" -dsco TITLE=%LAYER_ILOT_Z20% -nln %LAYER_ILOT_Z20%

ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_SURFACE_Z13%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_SURFACE_Z13%" -dsco TITLE=%LAYER_SURFACE_Z13% -nln %LAYER_SURFACE_Z13%
ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_SURFACE_Z15%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_SURFACE_Z15%" -dsco TITLE=%LAYER_SURFACE_Z15% -nln %LAYER_SURFACE_Z15%
ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_SURFACE_Z17%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_SURFACE_Z17%" -dsco TITLE=%LAYER_SURFACE_Z17% -nln %LAYER_SURFACE_Z17%

ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_PONCTUEL_Z21%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_PONCTUEL_Z21%" -dsco TITLE=%LAYER_PONCTUEL_Z21% -nln %LAYER_PONCTUEL_Z21%

ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_LINEAIRE_Z17%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_LINEAIRE_Z17%" -dsco TITLE=%LAYER_LINEAIRE_Z17% -nln %LAYER_LINEAIRE_Z17%
ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_LINEAIRE_Z21%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_LINEAIRE_Z21%" -dsco TITLE=%LAYER_LINEAIRE_Z21% -nln %LAYER_LINEAIRE_Z21%

ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_LINEAIRE_Z17%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_LINEAIRE_Z17%" -dsco TITLE=%LAYER_LINEAIRE_Z17% -nln %LAYER_LINEAIRE_Z17%
ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_LINEAIRE_Z21%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_LINEAIRE_Z21%" -dsco TITLE=%LAYER_LINEAIRE_Z21% -nln %LAYER_LINEAIRE_Z21%

ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_VOIES_ADMIN_Z14%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_VOIES_ADMIN_Z14%" -dsco TITLE=%LAYER_VOIES_ADMIN_Z14% -nln %LAYER_VOIES_ADMIN_Z14%
ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_VOIES_ADMIN_Z17%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_VOIES_ADMIN_Z17%" -dsco TITLE=%LAYER_VOIES_ADMIN_Z17% -nln %LAYER_VOIES_ADMIN_Z17%

ogr2ogr -if GPKG -f FlatGeobuf %CONVERT_FGB_OUTPUT_PATH%\%LAYER_VOIES_TRONCONS%.fgb %CONVERT_OUTPUT_PATH%\%CONVERT_OUTPUT_FILENAME%.gpkg -sql "SELECT * FROM %LAYER_VOIES_TRONCONS%" -dsco TITLE=%LAYER_VOIES_TRONCONS% -nln %LAYER_VOIES_TRONCONS%

ECHO Etape 6 - conversion en Flatgeobuf faite !

ECHO Etape 7 - copie sur le serveur en cours

SET SERVER_PATH=\\eureka\commun\equipemt\SIG Data Lille\Donnees\sources_externes
SET REPERTOIRE_LIMIT_ADMIN=\MEL\Limites_admin
SET REPERTOIRE_OCSMEL=\MEL\OCSMEL\
SET REPERTOIRE_RTGE=\MEL\RTGE\
SET REPERTOIRE_VOIRIE=\MEL\Voirie\

copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_COMMUNES%.fgb" "%SERVER_PATH%%REPERTOIRE_LIMIT_ADMIN%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_ILOT_Z20%.fgb" "%SERVER_PATH%%REPERTOIRE_OCSMEL%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_ILOT_Z13%.fgb" "%SERVER_PATH%%REPERTOIRE_OCSMEL%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_ILOT_Z12%.fgb" "%SERVER_PATH%%REPERTOIRE_OCSMEL%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_SURFACE_Z17%.fgb" "%SERVER_PATH%%REPERTOIRE_OCSMEL%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_SURFACE_Z15%.fgb" "%SERVER_PATH%%REPERTOIRE_OCSMEL%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_SURFACE_Z13%.fgb" "%SERVER_PATH%%REPERTOIRE_OCSMEL%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_PONCTUEL_Z21%.fgb" "%SERVER_PATH%%REPERTOIRE_RTGE%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_LINEAIRE_Z21%.fgb" "%SERVER_PATH%%REPERTOIRE_RTGE%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_LINEAIRE_Z17%.fgb" "%SERVER_PATH%%REPERTOIRE_RTGE%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_VOIES_ADMIN_Z14%.fgb" "%SERVER_PATH%%REPERTOIRE_VOIRIE%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_VOIES_ADMIN_Z17%.fgb" "%SERVER_PATH%%REPERTOIRE_VOIRIE%"
copy /B /V /Y "%CONVERT_FGB_OUTPUT_PATH%\%LAYER_VOIES_TRONCONS%.fgb" "%SERVER_PATH%%REPERTOIRE_VOIRIE%"

ECHO Etape 7 - copie sur le serveur faite

rem Enregistrer l'heure de fin
set ENDTIME=%TIME%

rem Convertir STARTTIME et ENDTIME en secondes
for /f "tokens=1-3 delims=:" %%a in ("%STARTTIME%") do (
    set /a STARTSEC=3600*1%%a+60*1%%b+1%%c
)
for /f "tokens=1-3 delims=:" %%a in ("%ENDTIME%") do (
    set /a ENDSEC=3600*1%%a+60*1%%b+1%%c
)

rem Calculer la différence en secondes
set /a DELTA=%ENDSEC%-%STARTSEC%

rem Convertir DELTA en heures, minutes et secondes
set /a HOURS=%DELTA% / 3600
set /a DELTA=%DELTA% %% 3600
set /a MINUTES=%DELTA% / 60
set /a SECONDS=%DELTA% %% 60

rem Afficher le temps d'exécution total
echo Temps d'execution total : %HOURS%h. %MINUTES%min. %SECONDS%sec.

echo Fini !
