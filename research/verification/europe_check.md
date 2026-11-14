<!-- Written by AI on 2026.11.14 by model claude opus 5.5: the output of europe_check.py behind research/europe-sources.md. -->

# europe_check.py output, 14 November 2026

CSI by lead time. Wet means 0.1 mm/h or more. DWD and MET Norway: rainy issue times from 12 to 14 November, scored against each service's own radar; the second block in each country is the 150 places used for the hourly models. Netherlands: the 86 cases of season.py against KNMI's gauge-adjusted radar.

```
Netherlands: 86 KNMI cases from season.py, 48 places
  KNMI plain forecast          5-30 0.767  35-60 0.578  65+ 0.458  all 0.555
  perfect hourly forecast      5-30 0.631  35-60 0.605  65+ 0.644  all 0.631
  best_match, wet if >= 0.1 mm 5-30 0.384  35-60 0.361  65+ 0.372  all 0.372
  best_match, wet if >= 0.2 mm 5-30 0.380  35-60 0.362  65+ 0.380  all 0.376
  best_match, wet if >= 0.5 mm 5-30 0.317  35-60 0.333  65+ 0.340  all 0.333
  ecmwf_ifs025, wet if >= 0.1 mm 5-30 0.312  35-60 0.303  65+ 0.320  all 0.314
  ecmwf_ifs025, wet if >= 0.2 mm 5-30 0.349  35-60 0.354  65+ 0.381  all 0.366
  ecmwf_ifs025, wet if >= 0.5 mm 5-30 0.320  35-60 0.332  65+ 0.355  all 0.340
  icon_d2, wet if >= 0.1 mm    5-30 0.430  35-60 0.425  65+ 0.454  all 0.441
  icon_d2, wet if >= 0.2 mm    5-30 0.424  35-60 0.441  65+ 0.466  all 0.449
  icon_d2, wet if >= 0.5 mm    5-30 0.361  35-60 0.387  65+ 0.407  all 0.390
  knmi_seamless, wet if >= 0.1 mm 5-30 0.384  35-60 0.361  65+ 0.372  all 0.372
  knmi_seamless, wet if >= 0.2 mm 5-30 0.380  35-60 0.362  65+ 0.380  all 0.376
  knmi_seamless, wet if >= 0.5 mm 5-30 0.317  35-60 0.333  65+ 0.340  all 0.333
  KNMI minus ICON-D2 >= 0.2 mm, 78 days: 5-30 +0.343 (+0.281 to +0.403)  35-60 +0.137 (+0.100 to +0.179)  65+ -0.008 (-0.041 to +0.028)  all +0.105 (+0.073 to +0.141)


dwd Germany: 16 issue times, 12 Nov 19:00 to 13 Nov 02:30 UTC, 61338 place-issues
  radar nowcast                5-30 0.869  35-60 0.716  65+ 0.573  all 0.678
  rain stays as it is          5-30 0.738  35-60 0.651  65+ 0.578  all 0.635
  perfect hourly forecast      5-30 0.787  35-60 0.740  65+ 0.733  all 0.749
  on 150 sampled places:
  radar nowcast                5-30 0.852  35-60 0.724  65+ 0.607  all 0.695
  rain stays as it is          5-30 0.751  35-60 0.668  65+ 0.589  all 0.648
  perfect hourly forecast      5-30 0.815  35-60 0.772  65+ 0.771  all 0.783
  best_match, wet if >= 0.1 mm 5-30 0.671  35-60 0.665  65+ 0.661  all 0.665
  best_match, wet if >= 0.2 mm 5-30 0.692  35-60 0.691  65+ 0.696  all 0.694
  best_match, wet if >= 0.5 mm 5-30 0.599  35-60 0.601  65+ 0.603  all 0.601
  ecmwf_ifs025, wet if >= 0.1 mm 5-30 0.493  35-60 0.492  65+ 0.496  all 0.494
  ecmwf_ifs025, wet if >= 0.2 mm 5-30 0.634  35-60 0.625  65+ 0.619  all 0.624
  ecmwf_ifs025, wet if >= 0.5 mm 5-30 0.550  35-60 0.548  65+ 0.543  all 0.546
  icon_d2, wet if >= 0.1 mm    5-30 0.672  35-60 0.669  65+ 0.665  all 0.668
  icon_d2, wet if >= 0.2 mm    5-30 0.695  35-60 0.697  65+ 0.701  all 0.699
  icon_d2, wet if >= 0.5 mm    5-30 0.599  35-60 0.601  65+ 0.603  all 0.601

dwd Austria: 24 issue times, 12 Nov 19:00 to 13 Nov 06:30 UTC, 7914 place-issues
  radar nowcast                5-30 0.876  35-60 0.777  65+ 0.681  all 0.753
  rain stays as it is          5-30 0.850  35-60 0.745  65+ 0.630  all 0.711
  perfect hourly forecast      5-30 0.901  35-60 0.875  65+ 0.877  all 0.883
  on 150 sampled places:
  radar nowcast                5-30 0.870  35-60 0.771  65+ 0.675  all 0.747
  rain stays as it is          5-30 0.840  35-60 0.733  65+ 0.619  all 0.700
  perfect hourly forecast      5-30 0.895  35-60 0.867  65+ 0.870  all 0.876
  best_match, wet if >= 0.1 mm 5-30 0.713  35-60 0.704  65+ 0.686  all 0.698
  best_match, wet if >= 0.2 mm 5-30 0.726  35-60 0.720  65+ 0.705  all 0.715
  best_match, wet if >= 0.5 mm 5-30 0.713  35-60 0.714  65+ 0.710  all 0.712
  ecmwf_ifs025, wet if >= 0.1 mm 5-30 0.687  35-60 0.663  65+ 0.618  all 0.647
  ecmwf_ifs025, wet if >= 0.2 mm 5-30 0.702  35-60 0.687  65+ 0.654  all 0.675
  ecmwf_ifs025, wet if >= 0.5 mm 5-30 0.704  35-60 0.696  65+ 0.679  all 0.690
  icon_d2, wet if >= 0.1 mm    5-30 0.713  35-60 0.704  65+ 0.686  all 0.698
  icon_d2, wet if >= 0.2 mm    5-30 0.726  35-60 0.720  65+ 0.705  all 0.715
  icon_d2, wet if >= 0.5 mm    5-30 0.713  35-60 0.714  65+ 0.710  all 0.712

dwd Switzerland: 18 issue times, 12 Nov 19:00 to 13 Nov 03:30 UTC, 4898 place-issues
  radar nowcast                5-30 0.804  35-60 0.653  65+ 0.555  all 0.641
  rain stays as it is          5-30 0.786  35-60 0.672  65+ 0.597  all 0.662
  perfect hourly forecast      5-30 0.850  35-60 0.807  65+ 0.800  all 0.815
  on 150 sampled places:
  radar nowcast                5-30 0.797  35-60 0.652  65+ 0.544  all 0.633
  rain stays as it is          5-30 0.793  35-60 0.673  65+ 0.602  all 0.667
  perfect hourly forecast      5-30 0.852  35-60 0.809  65+ 0.804  all 0.818
  best_match, wet if >= 0.1 mm 5-30 0.556  35-60 0.536  65+ 0.498  all 0.523
  best_match, wet if >= 0.2 mm 5-30 0.555  35-60 0.535  65+ 0.500  all 0.524
  best_match, wet if >= 0.5 mm 5-30 0.518  35-60 0.501  65+ 0.475  all 0.493
  ecmwf_ifs025, wet if >= 0.1 mm 5-30 0.548  35-60 0.518  65+ 0.465  all 0.499
  ecmwf_ifs025, wet if >= 0.2 mm 5-30 0.561  35-60 0.538  65+ 0.494  all 0.523
  ecmwf_ifs025, wet if >= 0.5 mm 5-30 0.562  35-60 0.543  65+ 0.505  all 0.530
  icon_d2, wet if >= 0.1 mm    5-30 0.556  35-60 0.536  65+ 0.498  all 0.523
  icon_d2, wet if >= 0.2 mm    5-30 0.555  35-60 0.535  65+ 0.500  all 0.524
  icon_d2, wet if >= 0.5 mm    5-30 0.518  35-60 0.501  65+ 0.475  all 0.493


met Norway: 28 issue times, 12 Nov 19:00 to 14 Nov 16:30 UTC, 91054 place-issues
  radar nowcast                5-30 0.527  35-60 0.296  65+ 0.171  all 0.274
  rain stays as it is          5-30 0.373  35-60 0.263  65+ 0.232  all 0.274
  perfect hourly forecast      5-30 0.521  35-60 0.489  65+ 0.523  all 0.514
  on 150 sampled places:
  radar nowcast                5-30 0.547  35-60 0.298  65+ 0.171  all 0.280
  rain stays as it is          5-30 0.381  35-60 0.277  65+ 0.252  all 0.290
  perfect hourly forecast      5-30 0.515  35-60 0.498  65+ 0.535  all 0.520
  best_match, wet if >= 0.1 mm 5-30 0.204  35-60 0.204  65+ 0.209  all 0.207
  best_match, wet if >= 0.2 mm 5-30 0.212  35-60 0.214  65+ 0.223  all 0.218
  best_match, wet if >= 0.5 mm 5-30 0.191  35-60 0.194  65+ 0.208  all 0.200
  ecmwf_ifs025, wet if >= 0.1 mm 5-30 0.198  35-60 0.199  65+ 0.202  all 0.200
  ecmwf_ifs025, wet if >= 0.2 mm 5-30 0.233  35-60 0.234  65+ 0.237  all 0.235
  ecmwf_ifs025, wet if >= 0.5 mm 5-30 0.257  35-60 0.263  65+ 0.274  all 0.267
  metno_seamless, wet if >= 0.1 mm 5-30 0.204  35-60 0.204  65+ 0.209  all 0.207
  metno_seamless, wet if >= 0.2 mm 5-30 0.212  35-60 0.214  65+ 0.223  all 0.218
  metno_seamless, wet if >= 0.5 mm 5-30 0.191  35-60 0.194  65+ 0.208  all 0.200

met Sweden: 38 issue times, 12 Nov 19:00 to 13 Nov 15:30 UTC, 136234 place-issues
  radar nowcast                5-30 0.606  35-60 0.393  65+ 0.273  all 0.377
  rain stays as it is          5-30 0.516  35-60 0.341  65+ 0.254  all 0.338
  perfect hourly forecast      5-30 0.648  35-60 0.602  65+ 0.627  all 0.626
  on 150 sampled places:
  radar nowcast                5-30 0.606  35-60 0.409  65+ 0.283  all 0.386
  rain stays as it is          5-30 0.517  35-60 0.352  65+ 0.263  all 0.346
  perfect hourly forecast      5-30 0.663  35-60 0.625  65+ 0.649  all 0.646
  best_match, wet if >= 0.1 mm 5-30 0.170  35-60 0.169  65+ 0.166  all 0.168
  best_match, wet if >= 0.2 mm 5-30 0.199  35-60 0.200  65+ 0.199  all 0.199
  best_match, wet if >= 0.5 mm 5-30 0.258  35-60 0.256  65+ 0.246  all 0.252
  ecmwf_ifs025, wet if >= 0.1 mm 5-30 0.148  35-60 0.146  65+ 0.142  all 0.145
  ecmwf_ifs025, wet if >= 0.2 mm 5-30 0.187  35-60 0.185  65+ 0.182  all 0.184
  ecmwf_ifs025, wet if >= 0.5 mm 5-30 0.234  35-60 0.233  65+ 0.223  all 0.229
  metno_seamless, wet if >= 0.1 mm 5-30 0.170  35-60 0.169  65+ 0.166  all 0.168
  metno_seamless, wet if >= 0.2 mm 5-30 0.199  35-60 0.200  65+ 0.199  all 0.199
  metno_seamless, wet if >= 0.5 mm 5-30 0.258  35-60 0.256  65+ 0.246  all 0.252

met Finland: 86 issue times, 12 Nov 19:00 to 14 Nov 14:30 UTC, 270352 place-issues
  radar nowcast                5-30 0.771  35-60 0.618  65+ 0.511  all 0.600
  rain stays as it is          5-30 0.686  35-60 0.555  65+ 0.472  all 0.545
  perfect hourly forecast      5-30 0.777  35-60 0.747  65+ 0.768  all 0.765
  on 150 sampled places:
  radar nowcast                5-30 0.755  35-60 0.596  65+ 0.492  all 0.581
  rain stays as it is          5-30 0.677  35-60 0.540  65+ 0.451  all 0.528
  perfect hourly forecast      5-30 0.770  35-60 0.734  65+ 0.756  all 0.754
  best_match, wet if >= 0.1 mm 5-30 0.400  35-60 0.400  65+ 0.399  all 0.400
  best_match, wet if >= 0.2 mm 5-30 0.474  35-60 0.474  65+ 0.475  all 0.474
  best_match, wet if >= 0.5 mm 5-30 0.507  35-60 0.507  65+ 0.508  all 0.507
  ecmwf_ifs025, wet if >= 0.1 mm 5-30 0.391  35-60 0.392  65+ 0.392  all 0.392
  ecmwf_ifs025, wet if >= 0.2 mm 5-30 0.496  35-60 0.497  65+ 0.499  all 0.497
  ecmwf_ifs025, wet if >= 0.5 mm 5-30 0.493  35-60 0.494  65+ 0.497  all 0.495
  metno_seamless, wet if >= 0.1 mm 5-30 0.400  35-60 0.400  65+ 0.399  all 0.400
  metno_seamless, wet if >= 0.2 mm 5-30 0.474  35-60 0.474  65+ 0.475  all 0.474
  metno_seamless, wet if >= 0.5 mm 5-30 0.507  35-60 0.507  65+ 0.508  all 0.507
```
