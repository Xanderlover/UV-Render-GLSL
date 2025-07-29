extends MeshInstance2D


var rd : RenderingDevice

var img_size := 512
var use_mipmaps : bool = false

var img_buffer : RID


func _ready() -> void:
	init_compute()

	## OUTPUTTED IMAGE
	var output_data : PackedByteArray = rd.texture_get_data(img_buffer, 0)
	var output_img := Image.create_from_data(img_size, img_size, use_mipmaps, Image.FORMAT_RGBAF, output_data)
	
	## DDDisplay it
	var output_img_tex := ImageTexture.create_from_image(output_img)
	texture = output_img_tex


func init_compute() -> void:
	# Create a local rendering device.
	rd = RenderingServer.create_local_rendering_device()

	# Load GLSL shader
	var shader_file := load("res://render_uv/render_uv.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	var shader := rd.shader_create_from_spirv(shader_spirv)

	### Prepare our img data
	var format := RDTextureFormat.new()
	format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	format.width = img_size
	format.height = img_size
	format.usage_bits = \
			RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | \
			RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT | \
			RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	img_buffer = rd.texture_create(format, RDTextureView.new())

	# Create a uniform to assign the buffer to the rendering device
	var uniform := RDUniform.new()
	uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	uniform.binding = 0 # this needs to match the "binding" in our shader file
	uniform.add_id(img_buffer)

	# Create a compute pipeline
	var uniform_set := rd.uniform_set_create([uniform], shader, 0) # the last parameter (the 0) needs to match the "set" in our shader file
	var pipeline := rd.compute_pipeline_create(shader)

	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_dispatch(compute_list, 8, 8, 1)
	rd.compute_list_end()

	# Submit to GPU and wait for sync
	rd.submit()
	rd.sync()
