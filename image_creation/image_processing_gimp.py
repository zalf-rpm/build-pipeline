#!/usr/bin/python
# -*- coding: UTF-8

num_files, files = pdb.file_glob("*.jpg", 1)
for file in files:
    image = pdb.gimp_file_load(file, file)
    drawable = pdb.gimp_image_get_active_layer(image)
    width = pdb.gimp_image_width(image)
    height = pdb.gimp_image_height(image)
    pdb.gimp_image_scale(image, width*0.50, height*0.50)
    newfilename = "klein/" + file[:-4] + "_small.jpg"
    pdb.gimp_file_save(image, drawable, newfilename, newfilename)
    pdb.gimp_image_delete(image)