;+ 
; NAME:
; lris_flux   
;   Version 1.1
;
; PURPOSE:
;    Plots any array interactively
;
; CALLING SEQUENCE:
;   
;   spec = x_apall(ydat, [head])
;
; INPUTS:
;   ydat       - Values 
;   [head]     - Header
;
; RETURNS:
;
; OUTPUTS:
;
; OPTIONAL KEYWORDS:
;   wave       - wavelength array
;   DISPLAY    - Display the sky subtracted image with xatv
;   OVR        - String array for ov region:  '[2050:2100, *]'
;   ERROR      - Variance array
;
; OPTIONAL OUTPUTS:
;
; COMMENTS:
;
; EXAMPLES:
;   kast_calibstd, kast, 0, 1, 0
;
;
; PROCEDURES/FUNCTIONS CALLED:
;
; REVISION HISTORY:
;   29-Aug-2003 Written by JXP
;-
;------------------------------------------------------------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

function lris_flux, wave, spec, flux_fil, SIG=sig, FSIG=fsig, EXP=exp

;
  if  N_params() LT 3  then begin 
      print,'Syntax - ' + $
        'flux = lris_flux( wave, spec, flux_fil, SIG=, FSIG=)  [v1.0]'
    return, -1
  endif 

  if not keyword_set( EXP ) then exp = 1.

  ;; bset
  bset = xmrdfits(flux_fil, 1, /silent)

  ;; Sensitivity function
  sens = bspline_valu(wave, bset)

  ;; Sig
  if keyword_set( SIG ) then fsig = sig * sens / exp


  print, 'lris_flux: All Done!'
  return, spec * sens / exp
end
