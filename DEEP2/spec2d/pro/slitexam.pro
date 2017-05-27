pro slitexam,  file, result, lineparams=lineparams, noplot=noplot, $
               nlsky=nlsky,totalexp=totalexp
;+.
; NAME:
;    slitexam
;
; PURPOSE:
;    sums multiple frames generated by spslit, does CR rejection
;
; CALLING SEQUENCE:
;   slitexam, file, result
; 
; INPUTS:
;    file -- string filename of relevant spSlit*.fits file
; 
; OPTIONAL OUTPUTS:
;    lineparams -- array of structures containing parameters of gauss 
;                   fits to skylines.  Centers, amplitudes, and sigmas
;	
; KEYWORDS:
;    noplot -- if set, skips the ATV plot
;    NLSKY  -- if set, performs a nonlocal sky fit and sky
;              subtraction on slits with <12 sky rows.
;              If NLSKY = 2 or NLSKY = 'all', NLSKY is performed for
;              all slitlets. 
; OUTPUTS:
;   result -- structure containing flux, ivar, and map of pixels
;             rejected in various frames (CR rejected), weighted sum
;             of object-sky.
;   totalexp -- total exposure time of all frames
; 
; COMMENTS:
;  The output structure has the dimensions of the slitlet, with the
;  flux being an invvar weighted average, ivar the sum of the input
;  invvar, mask is as the spslit mask, and crmask = 2^i where i
;  is the frame in which a CR was
;  expunged.
;
; REVISION HISTORY:
;  07jun02 MD
;  24-July-2002 DPF modified to do sky fit AFTER image combine
;  29-July-2002 DPF No... do sky removal before image combine
;----------------------------------------------------------------------

  result = 0
  status = 0
  lineparams=0

  totalexp=0.
  if n_elements(nlsky) eq 0 then nlsky=0
  if size(nlsky,/TYPE) eq 7 then if nlsky eq 'all' OR nlsky eq 'ALL' then $
       nlsky = 2 else nlsky=0
  
  fits_info, file, n_ext=n_ext, /silent
  nexp = n_ext/2   ; every other HDU is a bspline
; read each HDU
  for i=1, nexp do begin 
    data_in = mrdfits(file, 2*i-1, header,/silent, status=status)

    crmask = (data_in.infomask AND 8b) eq 8b

    chipno=sxpar(header,'CHIPNO')
    totalexp=totalexp+sxpar(header,'EXPTIME')
    if (size(data_in, /n_dimen) eq 0) then status = -2 else begin 
       sset = mrdfits(file, 2*i, /silent, status=status)
       nrows =  (size(data_in.flux, /dimen))[1]
       ; use existing bspline skymodel if NLSKY is not set


       if NLSKY ne 0 then begin
           if strpos(file,'spSlit') eq 0 then objfile='./'+file else $
		objfile=file
           nframe=i
           nhalf=6
           presmooth=1
           skybsplines=0
           
           nsky = total(data_in.skyrow)
  
           if ( (nsky gt 12 AND nrows gt 33) OR data_in.slitwidth ge 2.) $
              AND nlsky NE 2 then begin
; a kludge, but should work
             result = {slitfn:-1}
             return
           endif
         badsky=data_in.flux*0b

; do the nonlocal sky fit
            deimos_skysub_nl,  objfile, nframe, nhalf, subflux,$
                     skymodel=skymodel,  skybsplines=skybsplines, $
                     deweighting= 50., npoly = 6, $
                     presmooth=presmooth,crmask=crmask


            if n_elements(subflux) eq 1 then begin           
; a kludge, but should work
                result = {slitfn:-1}
                return
            endif else begin
                data_in.flux=subflux
                ivarmask=data_in.ivar eq 0.
                ivarmask=dilate(ivarmask,intarr(3)+1) OR ivarmask

                if presmooth then begin
		     invivar=1./data_in.ivar
 		     wh=where(finite(invivar) eq 0B, badct)
		     if badct ge 1 then invivar[wh]=0.
		     data_in.ivar=1./(1./16.*shift(invivar,1,0)+ $
				      1./16.*shift(invivar,-1,0)+ $
				      1./4.*invivar) 
		     data_in.ivar=data_in.ivar*(ivarmask eq 0B)

                 endif

                 sky=0.
           endelse


	     if (i eq 1) then baddata = (crmask OR data_in.ivar eq 0) else $
             baddata = [[[baddata]], [[crmask OR data_in.ivar eq 0]]]

	

       endif else begin

; LOCAL SKY HERE

           wave = lambda_eval(data_in,/double)
           skymodel = bspline_valu(wave, sset,mask=skymask)
; set ivar = 0 where we have no good bspline
           data_in.ivar=data_in.ivar*skymask
           if n_elements(badsky) eq 0 then badsky=(1b-skymask) $
               else badsky=(badsky OR (1b-skymask))
           tweakdata=data_in
; it'd be nice not to have to do this twice, 
;but we really want to do a skytweak before the bspline

           deimos_skytweak, tweakdata, lineparams=lineparams, crmask=crmask
           if (i eq 1) then sky = skymodel else $
             sky = [[[sky]], [[skymodel]]]

           if (i eq 1) then baddata = (crmask OR data_in.ivar eq 0) else $
             baddata = [[[baddata]], [[crmask OR data_in.ivar eq 0]]]


        endelse

; mask pixels where we cross the
; vignetted region 

; if present, keep & merge pixel info array
;	useinfo=total(tag_names(data_in) eq 'INFOMASK') NE 0

;       if useinfo then begin
	 if (i eq 1) then infomask = byte(data_in.infomask) else $
         infomask = byte(data_in.infomask) OR infomask
;	endif else infomask=data_in.mask*0b

; mask all vignetted pixels on red side, for now
;	if chipno gt 4 AND useinfo then $
	if chipno gt 4 then $
		vig_mask=(data_in.infomask AND 1b) EQ 1b $
		 else $
                vig_mask=(data_in.mask AND 8b) EQ 8b
	
	isdata=(data_in.mask AND 4b) eq 0

        data_in.flux=data_in.flux*(vig_mask eq 0b)*isdata

        data_in.ivar=data_in.ivar*(vig_mask eq 0b)*isdata
; experiment: deweight CRs
;        data_in.ivar=data_in.ivar/(1.+9999.*crmask)

	data_in.mask = data_in.mask OR 8B*vig_mask
        
       if (i eq 1) then bitmask = byte(data_in.mask) else $
          bitmask = byte(data_in.mask) OR bitmask


       if (i eq 1) then data = data_in else $
          data = [data, data_in]
    endelse
  endfor 

  if status NE 0 then return

  clean = (data.flux-sky)*((data.mask AND 4B) EQ 0b)
  clean=clean*(data.flux ne 0.)

  if n_elements(baddata) gt 0 then begin
	if nexp gt 1 then nbad=total(baddata,3) 
        avg = avsigclip(clean, data.ivar,inmask=1b-baddata)
   endif else begin
       nbad=0
       avg = avsigclip(clean, data.ivar)
   endelse

  if nexp gt 2 then avg.ivar=avg.ivar*(nbad lt nexp-1)

;  if NOT keyword_set(noplot) then $
;      atv, [[avg.flux], [data], [data[0].skymodel], $
;          [avg.mask]],  min=-5, max=20

  tags = tag_names(data)
  coeffexists = total(tags eq 'COEFF')
  polyflag = coeffexists EQ 0

; NOTE: THE FOLLOWING CODE DEFINED THE OLD BITMASK
;  bitmask = bitmask*1 OR (avg.mask NE 0)*128 OR (avg.mask EQ 2^nexp-1)*256

  lambda = lambda_eval(data[0],/double) ;get full solution
  dlambda = floatcompress(lambda-lambda[*, 0]#(fltarr(nrows)+1.))

  infomask=infomask OR badsky*4b

  if polyflag then begin
     result =  { flux:floatcompress(avg.flux), $
                 ivar:floatcompress(avg.ivar), $
                 mask:bitmask, crmask:byte(avg.mask AND 255B), $
                 lambda0:float(lambda[*, 0]), dlambda:dlambda, $
                 lambdax: data[0].lambdax, tiltx: data[0].tiltx, $ 
                 slitfn:data[0].slitfn,  dlam:data.dlam, $	
		 infomask: infomask }
  endif else begin
     result =  { flux:floatcompress(avg.flux), $
                 ivar:floatcompress(avg.ivar), $
                 mask:bitmask, crmask:byte(avg.mask AND 255B), $
                 lambda0:float(lambda[*, 0]), dlambda:dlambda, $
         func: data[0].func, xmin: data[0].xmin, xmax: data[0].xmax, $
                 coeff: data.coeff, $
                 slitfn:data[0].slitfn,  dlam:data.dlam, $
		 infomask: infomask }
  endelse               

return
end










