

// #sr  Start
cls
clear all
*++++++++++ Set your preferred folder ++++++++++
global path="D:\JJ Dropbox\J J\Study\UC Davis\Writings\Polarization\251202 (2026년 시작)"
*+++++++++++++++++++++++++++++++++++++++++++++++
cd "${path}"
do profile 

do install 

// #er 


// #sr   Data generation
import delimited "occ_level.csv", varnames(1) case(preserve) encoding(UTF-8) clear
keep ONETSOCCode Title dv_rating_alpha dv_rating_beta dv_rating_gamma
rename ONETSOCCode onetsoc2010code
save occ_level, replace 

* upper level 코드 생성
gen onetsoc2010code_6digit = substr(onetsoc2010code,1,7)   // 앞 6자리: 11-1011.00 → 11-1011
gen onetsoc2010code_4digit = substr(onetsoc2010code,1,5)   // 앞 6자리: 11-1011.00 → 11-10
gen onetsoc2010code_2digit = substr(onetsoc2010code,1,2)   // 앞 2자리: 11-1011.00 → 11
save occ_level, replace

use occ_level, clear 
preserve 
collapse (mean) dv_rating_alpha dv_rating_beta dv_rating_gamma, by(onetsoc2010code_6digit)
save occ_level_6digit, replace
restore 
preserve 
collapse (mean) dv_rating_alpha dv_rating_beta dv_rating_gamma, by(onetsoc2010code_4digit)
save occ_level_4digit, replace
restore 
preserve 
collapse (mean) dv_rating_alpha dv_rating_beta dv_rating_gamma, by(onetsoc2010code_2digit)
save occ_level_2digit, replace
restore 

forval year=2011/2020 {
    use Tasks`year', clear 
    rename onetsoccode onetsoc2010code
    save TasksGPT_SOC2010_`year', replace
}


use TasksGPT_SOC2010_2011, clear
forval year=2012/2020 {
    append using TasksGPT_SOC2010_`year'
}
merge m:1 taskid using RouCog_correct
keep if _merge==3
drop _merge 
rename (scoreGPT cognitivescoreGPT)(routinescore cognitivescore)
replace tt=5 if tt==1  //core
replace tt=1 if tt==0  //supplmental
collapse (mean) routinescore cognitivescore [pweight=tt], by(onetsoc2010code)
save roucog_compare_aiexposure, replace 
sort onetsoc2010code
gen idcheck=_n
gen soc2010=substr(onetsoc2010code,1,7)

* upper level 코드 생성
gen onetsoc2010code_6digit=substr(onetsoc2010code,1,7)
gen onetsoc2010code_4digit=substr(onetsoc2010code,1,5)
gen onetsoc2010code_2digit=substr(onetsoc2010code,1,2)
* 1차: 8자리 매칭
merge m:1 onetsoc2010code using occ_level
gen match_level = 8 if _merge == 3 
drop if _merge == 2  // using에만 있는 것 제거
drop _merge
* 2차: 6자리 매칭 (1차 실패한 것만)
merge m:1 onetsoc2010code_6digit using occ_level_6digit, update  // update 옵션 필수
replace match_level = 6 if _merge == 4 & match_level == .
drop if _merge == 2 // using에만 있는 것 제거
drop _merge
* 3차: 4자리 매칭 (1,2차 실패한 것만)
merge m:1 onetsoc2010code_4digit using occ_level_4digit, update  // update 옵션 필수
replace match_level = 4 if _merge == 4 & match_level == .
drop if _merge == 2 // using에만 있는 것 제거
drop _merge
* 4차: 2자리 매칭 (1,2,3차 실패한 것만)
merge m:1 onetsoc2010code_2digit using occ_level_2digit, update  // update 옵션 필수
replace match_level = 2 if _merge == 4 & match_level == .
drop if _merge == 2 // using에만 있는 것 제거
drop _merge

drop onetsoc2010code onetsoc2010code_6digit onetsoc2010code_4digit onetsoc2010code_2digit
count if missing(dv_rating_alpha)
count if missing(dv_rating_beta)
count if missing(dv_rating_gamma)
save TasksGPT_SOC2010, replace 



** 원본(occ변환전, task수준 레벨의 soc) roucog와 aiexposure 비교 
use roucog_compare_aiexposure, clear 
merge 1:1 onetsoc2010code using occ_level
gen aiexposure=( dv_rating_alpha+0.5* dv_rating_beta)
replace routinescore=1-routinescore  //! 반전. 반전한 것이 논문의 기준에 맞다.

corr aiexposure routinescore
scatter aiexposure routinescore, ///
    mcolor(black) ///
    ytitle("OpenAI's AI-exposure") ///
    xtitle("Routine score")
graph export scatter_aiexposure_routine.png, replace width(3000)

corr aiexposure cognitivescore
scatter aiexposure cognitivescore, ///
    mcolor(black) ///
    ytitle("OpenAI's AI-exposure") ///
    xtitle("Cognitive score")
graph export scatter_aiexposure_cognitive.png, replace width(3000)

preserve
    keep if cognitivescore>=0.5
    corr aiexposure routinescore
    scatter aiexposure routinescore, ///
        mcolor(black) ///
        ytitle("OpenAI's AI-exposure") ///
        xtitle("Routine score")
    graph export scatter_aiexposure_routine_highcog.png, replace width(3000)
restore

preserve
    keep if cognitivescore<0.5
    corr aiexposure routinescore
    scatter aiexposure routinescore, ///
        mcolor(black) ///
        ytitle("OpenAI's AI-exposure") ///
        xtitle("Routine score")
    graph export scatter_aiexposure_routine_lowcog.png, replace width(3000)
restore



import delimited "CPIAUCSL.csv", encoding(UTF-8) clear 
gen year=substr(date,1,4)
rename cpiaucsl cpi
collapse (mean) cpi, by(year)
destring year, replace
save cpi, replace 

import delimited "CPIAUCSL.csv", encoding(UTF-8) clear 
gen year=substr(date,1,4)
gen month=substr(date,6,2)
gen ym = ym(real(year), real(month))
format ym %tm
rename cpiaucsl cpi_monthly
collapse (mean) cpi_monthly, by(ym)
keep if inrange(ym, ym(2000,1), ym(2025,7))
save cpi_monthly, replace 


use CPIAUCSL-BLS, clear  
//! FRED download가 웹페이지 오류발생해서 CPIAUCSL.csv 업데이트 불가. BLS에서 대신 CPI 값 다운로드 받음.
// D:\JJ Dropbox\J J\Study\UC Davis\Writings\Polarization\251202 (2026년 시작)\BLS CPI 얻기
gen year=substr(date,1,4)
gen month=substr(date,6,2)
gen ym = ym(real(year), real(month))
format ym %tm
replace cpi=cpi[_n-1] if cpi==.
drop if ym >= ym(2026,5)
rename cpi cpi_monthly
collapse (mean) cpi_monthly, by(ym)
keep if inrange(ym, ym(2000,1), ym(2026,4))
save cpi_monthly_BLS, replace 



use TasksGPT_SOC2010, clear 
merge m:1 soc2010 using cenocc2010_edited
keep if _merge==3
drop soc2010 title _merge
gen occ2010new=substr(occ2010,1,4)
destring occ2010new, replace
drop occ2010
gen  occ2010=occ2010new
collapse (mean) routinescore cognitivescore dv_rating_alpha dv_rating_beta dv_rating_gamma, by(occ2010)

* upper level 코드 생성
gen occ3 = floor(occ2010/10)   // 앞 3자리: 8350 → 835
gen occ2 = floor(occ2010/100)  // 앞 2자리: 8350 → 83
save TasksGPT_4digit, replace

use TasksGPT_4digit, clear 
preserve 
collapse (mean) routinescore cognitivescore dv_rating_alpha dv_rating_beta dv_rating_gamma, by(occ3)
save TasksGPT_3digit, replace
restore 
preserve 
collapse (mean) routinescore cognitivescore dv_rating_alpha dv_rating_beta dv_rating_gamma, by(occ2)
save TasksGPT_2digit, replace
restore 



use cps_00029, clear   // CPS monthly
// cps_00028.dta 를 cps_00029.dta로 업데이트 (2026년5월29일 업데이트 날짜. 2026년4월이 가장 최신 연월)

//keep if sex==2

gen ym = ym(year, month)
gen ym2=ym
format ym %tm

merge m:1 ym using cpi_monthly_BLS, nogenerate

keep if inrange(age,18,60)
keep if inlist(empstat, 10, 12) & inlist(classwkr, 21, 22, 23)
rename (wtfinl incwage uhrswork1) (weight wage hourswork)
replace wage=wage/cpi_monthly*100

tab mish, nolabel
drop if cpsidp == 0  // 연결 불가능한 사람 제외

* 비교 가능한 쌍만 정의 (같은 4개월 그룹 내에서만)
* 그룹 1: mish 1,2,3,4
* 그룹 2: mish 5,6,7,8
gen group = .
replace group = 1 if inlist(mish, 1, 2, 3, 4)
replace group = 2 if inlist(mish, 5, 6, 7, 8)

sort cpsidp year month
by cpsidp: gen occ2010_prev = occ2010[_n-1]
by cpsidp: gen empstat_prev = empstat[_n-1]
by cpsidp: gen classwkr_prev = classwkr[_n-1]
by cpsidp: gen mish_prev = mish[_n-1]
by cpsidp: gen group_prev = group[_n-1]

* 같은 그룹 내 연속 조사만 유지 (4→5 제외)
gen valid_comparison = (group == group_prev) & (mish == mish_prev + 1)

* 전환자: 실업/다른직종 → 현재 직종 취업
gen employment = 1
gen transition = 0
replace transition = 1 if (occ2010 == occ2010_prev) & (valid_comparison == 1)

collapse (sum) transition employment (mean) hourswork [pw=weight], by(ym occ2010)
save CPS_transition, replace 



use CPS_transition, clear
gen occ3 = floor(occ2010/10)
gen occ2 = floor(occ2010/100)

* 1차: 4자리 매칭
merge m:1 occ2010 using TasksGPT_4digit
gen match_level = 4 if _merge == 3
drop if _merge == 2  // A에만 있는 것 제거
drop _merge

* 2차: 3자리 매칭 (1차 실패한 것만)
merge m:1 occ3 using TasksGPT_3digit, update  // update 옵션 필수
replace match_level = 3 if _merge == 4 & match_level == .
drop if _merge == 2 // A에만 있는 것 제거
drop _merge

* 3차: 2자리 매칭 (2차도 실패한 것만)
merge m:1 occ2 using TasksGPT_2digit, update  // update 옵션 필수
replace match_level = 2 if _merge == 4 & match_level == .
drop if _merge == 2 // A에만 있는 것 제거
drop _merge
sort occ2010 ym
save CPS_transition2, replace 


use CPS_transition2, clear 
keep occ2010 routinescore cognitivescore
duplicates drop 
twoway(scatter cognitivescore routinescore), ///
    xscale(range(0 1)) yscale(range(0 1)) ///
    xlabel(0(0.2)1) ylabel(0(0.2)1) xline(0.5) yline(0.5)

use CPS_transition2, clear 
gen routinescore_range=.
replace routinescore_range=1 if inrange(routinescore,0,1)
replace routinescore_range=0 if !inrange(routinescore,0,1) & routinescore!=.
tab routinescore_range  //! routinescore 범위가 전부 0~1 사이임을 확인. 값 반전 가능.

use CPS_transition2, clear 
gen aiexposure=( dv_rating_alpha+0.5* dv_rating_beta)
egen roucogscore=rowmean(cognitivescore routinescore)
scatter aiexposure roucogscore
scatter aiexposure cognitivescore
scatter aiexposure routinescore
// #er 


// #sr  Transition value check
use CPS_transition2, clear 
xtset occ2010 ym, monthly
sort transition
keep if occ2010==7700
sort ym
twoway (tsline transition)


use CPS_transition2, clear 
xtset occ2010 ym, monthly
tsfill
replace routinescore = 1 - routinescore   //! 값 반전함. 주의할것. 클수록 routine하고 작을수록 non-routine하도록 변경함. 

sort transition
//keep if occ2010== 9420  // 5360 //9420
rename transition transition2
rename hourswork hourswork2
bysort occ2010 (ym): ipolate transition2 ym, gen(transition3)  
bysort occ2010 (ym): ipolate hourswork2 ym, gen(hourswork3)  
tsfilter hp transition_hp = transition3, trend(transition) smooth(100) 
tsfilter hp hourswork_hp = hourswork3, trend(hourswork) smooth(100) 
twoway (tsline hourswork) (tsline hourswork2, lcolor(red))

bysort occ2010: egen transition_min=min(transition)
replace transition=transition-transition_min + 1 if transition_min<=0
replace transition2=transition2-transition_min + 1 if transition_min<=0
replace employment=employment-transition_min + 1 if transition_min<=0

bysort occ2010: egen hourswork_min=min(hourswork)
replace hourswork=hourswork-hourswork_min + 1 if hourswork_min<=0
replace hourswork2=hourswork2-hourswork_min + 1 if hourswork_min<=0
save CPS_transition3, replace 


use CPS_transition3, clear 
bysort occ2010 (ym): egen transition_start=min(ym)
bysort occ2010 (ym): egen transition_end=max(ym)
gen ym_nolab=ym
gen transition_start2=transition_start+1
gen transition_end2=transition_end-1
order occ2010 ym ym_nolab transition_start transition_start2 transition_end2 transition_end 
//drop if transition_start<=ym&ym<=transition_start2
//drop if transition_end2<=ym&ym<=transition_end
drop if ym<transition_start
drop if transition_end<ym
xtset occ2010 ym, monthly
drop transition_start transition_start2 transition_end transition_end2
rename transition2 transition_orig
save CPS_transition4, replace 

// #er 



// #sr  TWFE DiD 전처리
** intensity
clear all
set more off
set matsize 11000, perm

use CPS_transition4, clear 
gen aiexposure=(dv_rating_alpha+0.5* dv_rating_beta)*100
gen transition_rate=transition/employment*100

//keep if routinescore>=0.5&cognitivescore>=0.5
//keep if cognitivescore>=0.5
keep if cognitivescore<0.5   //! (중요) cognitive score의 모집단 설정 
//! >= 로 한 경우는 DiD 그래프 파일명을 high로 변경할것
//! < 로 한 경우는 DiD 그래프 파일명을 low로 변경할것

xtset occ2010 ym, monthly
drop if occ2010 == 294  // insufficient observations
egen occ=group(occ2010)
count if transition_rate<=0

gen employment_gr=(employment-L12.employment)/L12.employment*100

gen transition_rate_2023m1=transition_rate if ym==ym(2023,1)
egen transition_rate_2023m1_temp=mean(transition_rate_2023m1), by(occ2010)
gen transition_gr=(transition_rate-transition_rate_2023m1_temp)/transition_rate_2023m1_temp*100



//! routine score를 DiD의 주된 설명변수로 사용할 경우 활성화 (아래는 비활성화)
drop aiexposure
rename routinescore aiexposure2
//! OpenAI의 aiexposure를 DiD의 주된 설명변수로 사용할 경우 활성화 (위는 비활성화)
//rename aiexposure aiexposure2


** 이벤트 시 강도(처리그룹만)
//net install rangestat, from("http://fmwww.bc.edu/RePEc/bocode/r/") replace force
rangestat (mean) aiexposure2, interval(ym -12 0) by(occ2010)
gen intensity=aiexposure2_mean if ym==ym(2023,1)
egen aiexposure=mean(intensity), by(occ2010)
count if aiexposure<=0
drop if aiexposure==.

/*
* 이벤트 시 강도(처리그룹만)
drop aiexposure
rename cognitivescore aiexposure2
//net install rangestat, from("http://fmwww.bc.edu/RePEc/bocode/r/") replace force
rangestat (mean) aiexposure2, interval(ym -12 0) by(occ2010)
gen intensity=aiexposure2_mean if ym==ym(2023,1)
egen aiexposure=mean(intensity), by(occ2010)
count if aiexposure<=0
drop if aiexposure==.
*/

save CPS_transition5, replace 
// #er 


// #sr  TWFE DiD 추세제거
use CPS_transition5, clear 
adopath ++ "C:\ado\plus\m"

keep if inrange(ym,ym(2003,3),ym(2026,4))
gen month=month(dofm(ym))
egen periodidx = group(ym)   // periodidx 1 = 표본 최소 ym
* ★ 기간 수(NT)·기준기간(REFP=2022m12)·ym매핑(YM0)을 데이터에서 동적 산출.
*   하드코딩 269/277/238/517 제거 → 데이터(기간) 갱신 시 자동 일치 (r504·매핑오류 재발 방지).
quietly summarize periodidx
global NT = r(max)
quietly summarize ym
global YM0 = r(min) - 1                         // 플롯 매핑: ym = $YM0 + periodidx
quietly summarize periodidx if ym==ym(2022,12)
global REFP = r(max)                            // 기준기간(2022m12, 마지막 미처리월)의 periodidx
* 연속처리 × 시점 더미 상호작용 수동 생성 (ib는 factor#c.continuous 기준지정에 무효 → 수동 omit 필요)
forvalues t = 1/$NT {
    gen aiexp_d`t' = aiexposure * (periodidx == `t')
}
tab month, gen(dumm)

gen ymt=ym-517
gen ymt_sq=ymt*ymt
reg employment c.ymt#i.occ c.ymt_sq#i.occ i.occ if ym<ym(2023,1)   
predict double xbhat, xb
gen double employment_detrend = employment - xbhat   // [권고 3] 잔차 대신 예측치(표준 step-1; 진단·플롯라벨용)

// ── [권고 2·3] CASE B: pre-trend-adjusted continuous-dose event study + occ-클러스터 부트스트랩 ──
//   (NB) did2s/did_imputation은 공통 onset(2023m1)+never-treated 부재 → post 시간FE λ_t 비식별로
//   적용 불가(Gardner Asn 2.2·각주27; BJS Prop.1·Simultaneous Treatment). CASE B는 λ_t를 step-1
//   임퓨테이션이 아니라 step-2 i.ym으로 전기간 공동추정, dose×기간을 기간내 횡단 dose변이로 식별.
//   계수=ATT 아닌 dose-gradient slope. 강건성(wild bootstrap·추세차수·CGS2024)은 별도 권장.
// _es_twostep: step1 detrend(occ FE+추세, pre<2023m1, 시간FE 없음) → step2 event study(i.ym+dose×기간).
//   부트스트랩이 step-1 추정 불확실성을 step-2 추론으로 전파(Gardner §2.7 생성변수 SE 보정).
capture program drop _es_twostep
program _es_twostep, eclass
    tempvar xbh ydetr
    quietly reg employment c.ymt#i.__nid c.ymt_sq#i.__nid i.__nid if ym<ym(2023,1)
    quietly predict double `xbh', xb
    quietly gen double `ydetr' = employment - `xbh'
    quietly xtset __nid ym
    quietly xtreg `ydetr' aiexp_d1-aiexp_d`=$REFP-1' aiexp_d`=$REFP+1'-aiexp_d$NT i.ym dumm*, fe
    tempname bb
    matrix `bb' = J(1,$NT,0)
    local nm ""
    forvalues t = 1/$NT {
        local nm "`nm' c`t'"
    }
    matrix colnames `bb' = `nm'
    local ndrop = 0
    forvalues t = 1/$NT {
        if `t' == $REFP {
            matrix `bb'[1,`t'] = 0                  // 의도된 기준기간(2022m12)=0
        }
        else {
            capture matrix `bb'[1,`t'] = _b[aiexp_d`t']
            if _rc {
                matrix `bb'[1,`t'] = .              // 예기치못한 공선 drop→결측(0-채움 금지: SE 과소 방지)
                local ++ndrop
            }
        }
    }
    ereturn post `bb'
    ereturn scalar ndrop = `ndrop'                  // 정상=0. >0이면 그 rep에서 추가 공선.
end


capture program drop contdidreg
program contdidreg 
args i
    preserve
            * ── 점추정 = 관측 e(b), SE = occ-클러스터 부트스트랩 e(V) (권고 2) ──
            local reps = 999  // ★ 먼저 reps=49로 1회 검증(관측 ndrop=0·점추정 재현) 후 999. 무거움(수십분~).
            capture drop __nid
            gen __nid = occ    // 관측(비재표본)용 초기화; bootstrap이 재표본 시 idcluster로 고유 id 부여
            _es_twostep        // 관측 진단 실행
            di as txt "[diag] observed 추가 공선 drop = " e(ndrop) "  (정상 0; >0이면 중단·점검)"
            bootstrap, cluster(occ) idcluster(__nid) reps(`reps') seed(20260528) nodots: _es_twostep
            mat b = e(b)'
            mat v = vecdiag(e(V))'
            scalar invttail = invttail(e(N_clust)-1, 0.025)   // 클러스터-df t (원 invttail 취지 유지)
            matain b
            matain v
            mata se=sqrt(v)
            clear
            getmata b  
            getmata se
            gen lb=b-invttail*se
            gen ub=b+invttail*se
            gen t=_n
            replace t=t+$YM0
            tsset t, monthly
            format t %tm
    
            gen transition_rate=.
            gen employment_gr=.
            gen employment=.
            gen transition_gr=.
            gen employment_detrend=.
            gen hourswork=.

            label var transition_rate "Hire rate" 
            label var employment_gr "Employment Growth Rate" 
            label var employment_detrend "Employment Level" 
            label var transition_gr "Employment Growth Rate from 2023m1"

            * Create yearly ticks at January of each year
            local xlab ""
            forvalues yr = 2003/2026 {
                local m = 12*(`yr'-1960) + 1
                if `m' >= 518 & `m' <= 795 & mod(`yr'-2023,3)==0 {
                    local xlab "`xlab' `m' "`yr'""
                }
            }

            /*
            ** highcog
            twoway (rspike ub lb t, lcolor(gs0))(rcap ub lb t, msize(medsmall) lcolor(gs0))(scatter b t, mcolor(black) msymbol(O) msize(medium)), xline(755) yline(0) xtitle("") ytitle("") /// 
            legend(off) xlabel(`xlab') ///
            ylabel(-200000 -100000 0 100000 200000)
            graph export contdid`i'_highcog.eps, replace
            graph export contdid`i'_highcog.png, replace width(3000)
            */
            
            ** lowcog
            twoway (rspike ub lb t, lcolor(gs0))(rcap ub lb t, msize(medsmall) lcolor(gs0))(scatter b t, mcolor(black) msymbol(O) msize(medium)), xline(755) yline(0) xtitle("") ytitle("") /// 
            legend(off) xlabel(`xlab') ///
            ylabel(-200000 0 200000 400000)
            graph export contdid`i'_lowcog.eps, replace
            graph export contdid`i'_lowcog.png, replace width(3000)
            
            /*
            ** highcog AI
            twoway (rspike ub lb t, lcolor(gs0))(rcap ub lb t, msize(medsmall) lcolor(gs0))(scatter b t, mcolor(black) msymbol(O) msize(medium)), xline(755) yline(0) xtitle("") ytitle("") /// 
            legend(off) xlabel(`xlab') ///
            ylabel(-500 0 500)
            graph export contdid`i'_highcog_ai.eps, replace
            graph export contdid`i'_highcog_ai.png, replace width(3000)    
            */
            /*
            ** lowcog AI
            twoway (rspike ub lb t, lcolor(gs0))(rcap ub lb t, msize(medsmall) lcolor(gs0))(scatter b t, mcolor(black) msymbol(O) msize(medium)), xline(755) yline(0) xtitle("") ytitle("") /// 
            legend(off) xlabel(`xlab') ///
            ylabel(-500 0 500)
            graph export contdid`i'_lowcog_ai.eps, replace
            graph export contdid`i'_lowcog_ai.png, replace width(3000)      
            */    
    restore
end

contdidreg employment_detrend

// #er


// #sr  TWFE DiD 추세제거 (CASE B robustness — wild cluster bootstrap, step-2)
* 위 CASE B(occ 짝(pairs) 클러스터 부트스트랩)와 동일한 이벤트 스터디 점추정을 동일 그래프로
* 산출하되, 추론만 step-2 군집 wild bootstrap으로 대체한 강건성 점검이다.
* 동기: 파라미터 수(269 dose×기간 + 시간FE)가 클러스터 수(occ ≈ 123)를 크게 초과 → 짝 부트스트랩·
*       CRVE의 소표본 하방편의 우려. wild cluster bootstrap이 이 환경에서 더 방어적(Cameron-Miller 2015;
*       Webb 6점 가중은 MacKinnon-Webb).
* ★범위(정직 표기): 본 절차는 1단계 추세제거 결과 employment_detrend를 "고정"하고 step-2 잔차를
*   occ별 wild 가중으로 교란해 step-2만 재추정한다. 따라서 step-2 군집 추론의 강건성만 점검하며,
*   1단계(생성 종속변수) 추정 불확실성은 전파하지 않는다 — 그 부분은 위 짝 클러스터 부트스트랩이
*   담당한다. 두 점검은 상호보완적이며 어느 하나가 다른 하나를 대체하지 않는다.
* 데이터 준비부(aiexp_d*, dumm*, occ, ym)와 CASE B에서 만든 employment_detrend를 그대로 사용.
capture program drop contdidregwild
program contdidregwild
args i
    preserve
            local reps = 999   // ★ 먼저 49로 검증 후 999. step-2만 재추정하므로 짝 버전보다 가벼움.

            * ── (1) 실데이터 step-2 적합 → 점추정 + (적합·잔차) 분해 ──
            quietly xtset occ ym
            quietly xtreg `i' aiexp_d1-aiexp_d`=$REFP-1' aiexp_d`=$REFP+1'-aiexp_d$NT i.ym dumm*, fe
            quietly predict double s2fit, xbu        // a_i + λ_t + Σβ_k(...)
            quietly predict double uhat, e           // 특이오차 잔차
            * 분해 항등식 점검: `i' == s2fit + uhat (≈0 이어야 함; predict 분해 검증)
            quietly gen double _chk = `i' - s2fit - uhat
            quietly summarize _chk
            di as txt "[diag] 분해 잔차 max|.| = " max(abs(r(min)),abs(r(max))) "  (≈0이어야 함)"
            quietly drop _chk
            * 점추정 $NT-벡터 (이름기준; ref은 0)
            mat b = J($NT,1,0)
            forvalues k = 1/$NT {
                if `k' != $REFP {
                    capture mat b[`k',1] = _b[aiexp_d`k']
                }
            }
            * 클러스터(occ) 수 → 자유도
            tempvar tagocc
            egen `tagocc' = tag(occ)
            quietly count if `tagocc'
            local G = r(N)

            * ── (2) wild cluster bootstrap (Webb 6점 가중, occ 클러스터, step-2만 재추정) ──
            mat bsum = J($NT,1,0)
            mat bsq  = J($NT,1,0)
            set seed 20260528
            forvalues r = 1/`reps' {
                capture drop _u6 _w ybd
                * occ별 Webb 6점 가중(클러스터 내 동일): {-√1.5,-1,-√.5,√.5,1,√1.5}
                bysort occ (ym): gen double _u6 = ceil(6*runiform()) if _n==1
                bysort occ (ym): replace _u6 = _u6[1]
                gen double _w = .
                quietly replace _w = -sqrt(1.5) if _u6==1
                quietly replace _w = -1         if _u6==2
                quietly replace _w = -sqrt(0.5) if _u6==3
                quietly replace _w =  sqrt(0.5) if _u6==4
                quietly replace _w =  1         if _u6==5
                quietly replace _w =  sqrt(1.5) if _u6==6
                * 교란된 step-2 종속변수(w≡1이면 원자료로 환원) + step-2 재추정
                gen double ybd = s2fit + _w*uhat
                quietly xtreg ybd aiexp_d1-aiexp_d`=$REFP-1' aiexp_d`=$REFP+1'-aiexp_d$NT i.ym dumm*, fe
                forvalues k = 1/$NT {
                    if `k' != $REFP {
                        capture scalar _bk = _b[aiexp_d`k']
                        if !_rc {
                            mat bsum[`k',1] = bsum[`k',1] + _bk
                            mat bsq[`k',1]  = bsq[`k',1]  + _bk^2
                        }
                    }
                }
            }
            * ── (3) wild 부트스트랩 분산 → SE ──  v_k = (Σb² − (Σb)²/R)/(R−1)
            mat v = J($NT,1,0)
            forvalues k = 1/$NT {
                if `k' != $REFP {
                    mat v[`k',1] = (bsq[`k',1] - bsum[`k',1]^2/`reps') / (`reps'-1)
                }
            }
            scalar invttail = invttail(`G'-1, 0.025)   // 클러스터-df t

            matain b
            matain v
            mata se=sqrt(v)
            clear
            getmata b
            getmata se
            gen lb=b-invttail*se
            gen ub=b+invttail*se
            gen t=_n
            replace t=t+$YM0
            tsset t, monthly
            format t %tm

            gen transition_rate=.
            gen employment_gr=.
            gen employment=.
            gen transition_gr=.
            gen employment_detrend=.
            gen hourswork=.
            label var transition_rate "Hire rate"
            label var employment_gr "Employment Growth Rate"
            label var employment_detrend "Employment Level"
            label var transition_gr "Employment Growth Rate from 2023m1"

            * Create yearly ticks at January of each year
            local xlab ""
            forvalues yr = 2003/2026 {
                local m = 12*(`yr'-1960) + 1
                if `m' >= 518 & `m' <= 795 & mod(`yr'-2023,3)==0 {
                    local xlab "`xlab' `m' "`yr'""
                }
            }

            /*    
            ** highcog
            twoway (rspike ub lb t, lcolor(gs0))(rcap ub lb t, msize(medsmall) lcolor(gs0))(scatter b t, mcolor(black) msymbol(O) msize(medium)), xline(755) yline(0) xtitle("") ytitle("") /// 
            legend(off) xlabel(`xlab') ///
            ylabel(-200000 -100000 0 100000 200000)
            graph export contdid`i'_highcog_wild.eps, replace
            graph export contdid`i'_highcog_wild.png, replace width(3000)
            */
            
            ** lowcog
            twoway (rspike ub lb t, lcolor(gs0))(rcap ub lb t, msize(medsmall) lcolor(gs0))(scatter b t, mcolor(black) msymbol(O) msize(medium)), xline(755) yline(0) xtitle("") ytitle("") /// 
            legend(off) xlabel(`xlab') ///
            ylabel(-200000 0 200000 400000)
            graph export contdid`i'_lowcog_wild.eps, replace
            graph export contdid`i'_lowcog_wild.png, replace width(3000)
            
            /*
            ** highcog AI
            twoway (rspike ub lb t, lcolor(gs0))(rcap ub lb t, msize(medsmall) lcolor(gs0))(scatter b t, mcolor(black) msymbol(O) msize(medium)), xline(755) yline(0) xtitle("") ytitle("") /// 
            legend(off) xlabel(`xlab') ///
            ylabel(-500 0 500)
            graph export contdid`i'_highcog_ai_wild.eps, replace
            graph export contdid`i'_highcog_ai_wild.png, replace width(3000)    
            */ 
            /*
            ** lowcog AI
            twoway (rspike ub lb t, lcolor(gs0))(rcap ub lb t, msize(medsmall) lcolor(gs0))(scatter b t, mcolor(black) msymbol(O) msize(medium)), xline(755) yline(0) xtitle("") ytitle("") /// 
            legend(off) xlabel(`xlab') ///
            ylabel(-500 0 500)
            graph export contdid`i'_lowcog_ai_wild.eps, replace
            graph export contdid`i'_lowcog_ai_wild.png, replace width(3000)      
            */ 
    restore
end

contdidregwild employment_detrend

// #er


// #sr  Graph1
use RouCog_new, clear 

foreach var of varlist original_opus_score original_gpt_score {
    replace `var' = `var' + (runiform() - runiform(0.2, 0.8)) / 10
}

twoway (scatter original_opus_score original_gpt_score, msize(vtiny))(lfit original_opus_score original_gpt_score), ///
    xlabel(, labsize(medium)) ylabel(, labsize(medium)) ///
    xtitle("OPUS score", size(medium)) ///
    ytitle("GPT score", size(medium)) ///
    legend(off) xline(0.5) yline(0.5)
graph export "Graph1.eps", replace
// #er 


// #sr  Graph3
use RouCog_new, clear 
keep cognitivescore routinescore
foreach var of varlist _all {
    replace `var' = `var' + (runiform() - 0.5) / 10
}
scatter cognitivescore routinescore,  msize(vtiny) ///
    xlabel(, labsize(medium)) ylabel(, labsize(medium)) ///
    xtitle("Routine score", size(medium)) ///
    ytitle("Cognitive score", size(medium)) ///
    legend(size(Large)) xline(0.5) yline(0.5)
graph export "Graph3.pdf", replace
// #er 


// #sr  Graph4 
use TasksGPT_SOC2010, clear 
gen SOC=substr(soc2010,1,2)
destring SOC, replace 
label define labelname2 11 "Management" 13 "Business" 15 "Mathematical" 17 "Engineering" 19 "Social Science" 21 "Social Service" 23 "Legal" 25 "Education, Training" 27 "Arts, Design, Entertainment" 29 "Healthcare Practitioners" 31 "Healthcare Support" 33 "Protective Service" 35 "Food Preparation and Serving" ///
37 "Cleaning and Maintenance" 39 "Personal Care" 41 "Sales" 43 "Administrative Support" 45 "Farming, Fishing, and Forestry"  47 "Construction" 49 "Maintenance and Repair" 51 "Production"  53 "Transportation"
label values SOC labelname2
collapse (mean) cognitivescore routinescore, by(SOC)
scatter cognitivescore routinescore, mlabel(SOC) msize(big) ///
    xlabel(, labsize(medium)) ylabel(, labsize(medium)) ///
    xtitle("Routine score", size(medium)) ///
    ytitle("Cognitive score", size(medium)) ///
    legend(size(Large)) xline(0.5) yline(0.5) ///
    xsize(10) ysize(13)
graph export "Graph4.eps", replace
// #er 


// #sr  Table Walo
use IPUMSusa, clear 
keep occ1990 occsoc
rename occsoc soc2010
gen num=1
collapse (sum) num, by(soc2010 occ1990)
gsort soc2010 -num
gen d=0
replace d=1 if soc2010!=soc2010[_n-1]
keep if d==1
replace soc2010=substr(soc2010,1,2) + "-" + substr(soc2010,3,4)
save IPUMSusa_mergeready, replace

use IPUMSusa_mergeready, clear 
gen soc2010_X=substr(soc2010,1,6)
keep soc2010_X occ1990
gen num=1
collapse (sum) num, by(soc2010_X occ1990)
gsort soc2010_X -num
gen d=0
replace d=1 if soc2010_X!=soc2010_X[_n-1]
keep if d==1
rename occ1990 occ1990_X
save IPUMSusa_mergeready_X, replace 

use IPUMSusa_mergeready, clear 
gen soc2010_XX=substr(soc2010,1,5)
keep soc2010_XX occ1990
gen num=1
collapse (sum) num, by(soc2010_XX occ1990)
gsort soc2010_XX -num
gen d=0
replace d=1 if soc2010_XX!=soc2010_XX[_n-1]
keep if d==1
rename occ1990 occ1990_XX
save IPUMSusa_mergeready_XX, replace 

use IPUMSusa_mergeready, clear 
gen soc2010_XXX=substr(soc2010,1,4)
keep soc2010_XXX occ1990
gen num=1
collapse (sum) num, by(soc2010_XXX occ1990)
gsort soc2010_XXX -num
gen d=0
replace d=1 if soc2010_XXX!=soc2010_XXX[_n-1]
keep if d==1
rename occ1990 occ1990_XXX
save IPUMSusa_mergeready_XXX, replace 

use IPUMSusa_mergeready, clear 
gen soc2010_XXXXX=substr(soc2010,1,2)
keep soc2010_XXXXX occ1990
gen num=1
collapse (sum) num, by(soc2010_XXXXX occ1990)
gsort soc2010_XXXXX -num
gen d=0
replace d=1 if soc2010_XXXXX!=soc2010_XXXXX[_n-1]
keep if d==1
rename occ1990 occ1990_XXXXX
save IPUMSusa_mergeready_XXXXX, replace 

use TasksGPT_SOC2010, clear 
replace soc2010 = subinstr(trim(soc2010), " ", "", .)
gen soc2010_X=substr(soc2010,1,6)
gen soc2010_XX=substr(soc2010,1,5)
gen soc2010_XXX=substr(soc2010,1,4)
gen soc2010_XXXXX=substr(soc2010,1,2)
merge m:1 soc2010 using IPUMSusa_mergeready
rename _merge _merge_0
merge m:1 soc2010_X using IPUMSusa_mergeready_X
rename _merge _merge_X
merge m:1 soc2010_XX using IPUMSusa_mergeready_XX
rename _merge _merge_XX
merge m:1 soc2010_XXX using IPUMSusa_mergeready_XXX
rename _merge _merge_XXX
merge m:1 soc2010_XXXXX using IPUMSusa_mergeready_XXXXX
rename _merge _merge_XXXXX
gen occ=occ1990 if occ1990!=.
replace occ=occ1990_X if occ1990_X!=.&occ==.
replace occ=occ1990_XX if occ1990_XX!=.&occ==.
replace occ=occ1990_XXX if occ1990_XXX!=.&occ==.
replace occ=occ1990_XXXXX if occ1990_XXXXX!=.&occ==.
drop if routinescore==.
drop if occ==.
save Walo_temp, replace 

use Walo_temp, clear 
gen id=.
replace id=1 if inrange(occ,3,22)
replace id=2 if inrange(occ,23,37)
replace id=3 if occ==43
replace id=4 if inrange(occ,44,59)
replace id=5 if inrange(occ,64,68)
replace id=6 if inrange(occ,69,83)
replace id=7 if inrange(occ,84,89)
replace id=8 if inrange(occ,95,97)
replace id=9 if inrange(occ,98,106)
replace id=10 if inrange(occ,113,154)
replace id=11 if inrange(occ,155,163)
replace id=12 if inrange(occ,164,165)
replace id=13 if inrange(occ,166,173)
replace id=14 if inrange(occ,174,176)
replace id=15 if inrange(occ,178,179)
replace id=16 if inrange(occ,183,200)
replace id=17 if inrange(occ,203,208)
replace id=18 if inrange(occ,213,223)
replace id=19 if inrange(occ,224,225)
replace id=20 if inrange(occ,226,235)
replace id=21 if inrange(occ,243,256)
replace id=22 if inrange(occ,253,256)
replace id=23 if inrange(occ,258,277)
replace id=24 if occ==283
replace id=25 if occ==303
replace id=26 if occ==308
replace id=27 if inrange(occ,313,315)
replace id=28 if inrange(occ,316,323)
replace id=29 if inrange(occ,236,336)
replace id=30 if inrange(occ,337,344)
replace id=31 if inrange(occ,345,347)
replace id=32 if inrange(occ,348,349)
replace id=33 if inrange(occ,354,357)
replace id=34 if inrange(occ,359,373)
replace id=35 if inrange(occ,375,378)
replace id=36 if inrange(occ,379,389)
replace id=37 if inrange(occ,405,407)
replace id=38 if occ==415
replace id=39 if occ==417
replace id=40 if inrange(occ,418,423)
replace id=41 if inrange(occ,425,427)
replace id=42 if inrange(occ,434,444)
replace id=43 if inrange(occ,445,447)
replace id=44 if inrange(occ,448,455)
replace id=45 if inrange(occ,456,465)
replace id=46 if occ==503
replace id=47 if inrange(occ,505,519)
replace id=48 if inrange(occ,523,534)
replace id=49 if inrange(occ,535,549)
replace id=50 if occ==558
replace id=51 if inrange(occ,563,599)
replace id=52 if inrange(occ,614,617)
replace id=53 if occ==628
replace id=54 if inrange(occ,634,653)
replace id=55 if inrange(occ,657,659)
replace id=56 if inrange(occ,666,674)
replace id=57 if inrange(occ,675,684)
replace id=58 if inrange(occ,686,688)
replace id=59 if occ==693
replace id=60 if inrange(occ,694,699)
replace id=61 if inrange(occ,703,717)
replace id=62 if inrange(occ,719,724)
replace id=63 if inrange(occ,726,733)
replace id=64 if inrange(occ,734,736)
replace id=65 if inrange(occ,738,749)
replace id=66 if inrange(occ,753,779)
replace id=67 if inrange(occ,783,789)
replace id=68 if inrange(occ,796,799)
replace id=69 if inrange(occ,803,813)
replace id=70 if inrange(occ,823,825)
replace id=71 if inrange(occ,829,834)
replace id=72 if inrange(occ,844,859)
replace id=73 if inrange(occ,865,874)
replace id=74 if inrange(occ,875,889)

collapse (mean) routinescore, by(id)
drop if routinescore==.
egen rou_sd=sd(routinescore)
egen rou_mean=mean(routinescore)
replace routinescore=(routinescore-rou_mean)/rou_sd
keep id routinescore
save Walo_temp2, replace 


import delimited "Walo Data_add.csv", varnames(1) encoding(UTF-8) clear 
merge 1:1 id using Walo_temp2
replace routinescore=0 if routinescore==.
drop if id==.
label variable routinescore "AIRTI"
correlate employmentshare19802005 rtiautoranddorn rtiacemogluandautor rtigoosetal rtidenglerandmatthes rtimarcolinetal routinescore
matrix C = r(C)

* Display the matrix with two decimals
matrix list C, format(%4.2f)

// #er 

