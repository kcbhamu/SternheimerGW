#------------------------------------------------------------------------------
#
# This file is part of the SternheimerGW code.
# 
# Copyright (C) 2010 - 2018
# Henry Lambert, Martin Schlipf, and Feliciano Giustino
#
# SternheimerGW is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SternheimerGW is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with SternheimerGW. If not, see
# http://www.gnu.org/licenses/gpl.html .
#
#------------------------------------------------------------------------------
depend = "depend"
order = "order"
structure = {
"util": {
  depend: ["base", "lrmods"],
},
"data": {
  "algebra": {
    depend: ["base"],
  },
  "fft": {
    depend: ["base", "timing"],
  },
  "parallel": {
    depend: ["base"],
  },
  "timing": {
    depend: ["base"],
  },
},
"algo": {
  "analytic": {
    depend: ["base", "vendor",  "util", "data", "grid"],
  },
  "grid": {
    depend: ["base", "util", "data"],
  },
  "io": {
    depend: ["base", "pw", "lrmods", "vendor", "util", "grid"],
  },
  "linear_solver": {
    depend: ["base", "pw", "lrmods", "util", "data"]
  },
  "mesh": {
    depend: ["base", "pw", "util"],
  },
  "nscf": {
    depend: ["base", "pw", "lrmods", "util"],
  },
  "reorder": {
    depend: ["base"],
  },
  "setup": {
    depend: ["base", "pw", "lrmods", "util"],
  },
  "symmetry": {
    depend: ["base", "pw", "lrmods", "util"],
  },
  "teardown": {
    depend: ["base", "pw", "lrmods", "util", "data", "io"],
  },
  "truncation": {
    depend: ["base", "vendor", "util"],
  },
},
"phys": {
  "corr": {
    depend: ["base", "pw", "vendor", "util", "data", "algo", "driver", "coul", "green"],
  },
  "coul": {
    depend: ["base", "pw", "lrmods", "vendor", "util", "data", "algo", "postproc", "driver"],
  },
  "driver": {
    depend: ["base", "pw", "lrmods", "vendor", "util", "data", "algo"],
  },
  "exch": {
    depend: ["base", "pw", "lrmods", "vendor", "util", "data", "algo", "driver"],
  },
  "green": {
    depend: ["base", "pw", "vendor", "util", "data", "algo"],
  },
  "matrix_el": {
    depend: ["base", "pw", "lrmods", "vendor", "util", "data", "algo", "driver"],
  },  
  "postproc": {
    depend: ["base", "vendor", "algo"],
  },
},
}

def add_order_to_dict(struct):
  init_order_to_zero(struct)
  repeat_until_order_is_stable(struct)

def init_order_to_zero(struct):
  for key in struct:
    struct[key][order] = 0

def repeat_until_order_is_stable(struct):
  for it in range(len(struct)):
    update_order_of_all_element(struct)

def update_order_of_all_element(struct):
  for key in struct:
    struct[key][order] = get_order_depend_element(key, struct) + 1

def get_order_depend_element(key, struct):
  result = 0
  for dep in struct[key][depend]:
    if dep in struct:
      result = max(result, struct[dep][order])
  return result

for key in structure:
  if depend in structure[key]:
    structure[key][order] = 0
  else:
    add_order_to_dict(structure[key])

def sort_dict_by_order(struct):
  result = []
  for (key, value) in sorted(struct.iteritems(), key=lambda(key, value): value[order]):
    result.append(key)
  return result
