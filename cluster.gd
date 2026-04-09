[gd_scene format=3 uid="uid://cjep8ct00744g"]

[ext_resource type="Script" uid="uid://ch4a8k4rwcqmu" path="res://scripts/targetsphere.gd" id="1_55hr1"]
[ext_resource type="Texture2D" uid="uid://esp4wt8ecgpb" path="res://assets/kyklonTextures/BlueRockTexture-1.jpg" id="2_fp1gp"]

[sub_resource type="SphereMesh" id="SphereMesh_47k3f"]

[sub_resource type="StandardMaterial3D" id="StandardMaterial3D_cflii"]
albedo_texture = ExtResource("2_fp1gp")

[sub_resource type="SphereShape3D" id="SphereShape3D_cflii"]

[node name="TargetSphere" type="Area3D" unique_id=1742064879]
collision_layer = 2
script = ExtResource("1_55hr1")

[node name="mesh" type="MeshInstance3D" parent="." unique_id=957664965]
mesh = SubResource("SphereMesh_47k3f")
surface_material_override/0 = SubResource("StandardMaterial3D_cflii")

[node name="CollisionShape3D" type="CollisionShape3D" parent="." unique_id=1402803662]
shape = SubResource("SphereShape3D_cflii")

[connection signal="body_entered" from="." to="." method="TargetSphere"]
