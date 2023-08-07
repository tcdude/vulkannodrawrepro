#include <kinc/graphics4/graphics.h>
#include <kinc/graphics4/indexbuffer.h>
#include <kinc/graphics4/pipeline.h>
#include <kinc/graphics4/shader.h>
#include <kinc/graphics4/vertexbuffer.h>
#include <kinc/io/filereader.h>
#include <kinc/system.h>

#include <assert.h>
#include <stdlib.h>

#include "data_bad.h"
#include "data_good.h"

static kinc_g4_shader_t vertex_shader;
static kinc_g4_shader_t fragment_shader;
static kinc_g4_pipeline_t pipeline_g;
static kinc_g4_pipeline_t pipeline_b;
static kinc_g4_vertex_buffer_t vertices;
static kinc_g4_index_buffer_t indices;
static kinc_g4_constant_location_t sg_data_loc_g;
static kinc_g4_constant_location_t sg_data_loc_b;
static kinc_g4_constant_location_t i_time_loc_g;
static kinc_g4_constant_location_t i_time_loc_b;
static kinc_g4_constant_location_t i_resolution_loc_g;
static kinc_g4_constant_location_t i_resolution_loc_b;
static kinc_g4_constant_location_t sg_mouse_loc_g;
static kinc_g4_constant_location_t sg_mouse_loc_b;
static kinc_g4_constant_location_t sg_alpha_loc_g;
static kinc_g4_constant_location_t sg_alpha_loc_b;

#define HEAP_SIZE 1024 * 1024
static uint8_t *heap = NULL;
static size_t heap_top = 0;

static void *allocate(size_t size) {
  size_t old_top = heap_top;
  heap_top += size;
  assert(heap_top <= HEAP_SIZE);
  return &heap[old_top];
}

static void update(void *data) {
  kinc_g4_begin(0);
  kinc_g4_clear(KINC_G4_CLEAR_COLOR, 0, 0.0f, 0);

  // Draw call that goes through and draws what it is supposed to
  kinc_g4_set_pipeline(&pipeline_g);
  kinc_g4_set_vertex_buffer(&vertices);
  kinc_g4_set_index_buffer(&indices);
  kinc_g4_set_floats(sg_data_loc_g, sg_data_g, SG_DATA_SZ_G);
  kinc_g4_set_float2(sg_alpha_loc_g, 1.0f, 1.0f);
  kinc_g4_set_float2(sg_mouse_loc_g, 0, 0);
  kinc_g4_set_float2(i_resolution_loc_g, 1024, 768);
  kinc_g4_set_float(i_time_loc_g, 0);
  kinc_g4_draw_indexed_vertices();

  // Draw call that on Linux gets ignored (unable to capture with renderdoc) and
  // on Windows results in not drawing (but able to capture with renderdoc)
  kinc_g4_set_pipeline(&pipeline_b);
  kinc_g4_set_vertex_buffer(&vertices);
  kinc_g4_set_index_buffer(&indices);
  kinc_g4_set_floats(sg_data_loc_b, sg_data_b, SG_DATA_SZ_B);
  kinc_g4_set_float2(sg_alpha_loc_b, 1.0f, 1.0f);
  kinc_g4_set_float2(sg_mouse_loc_b, 0, 0);
  kinc_g4_set_float2(i_resolution_loc_b, 1024, 768);
  kinc_g4_set_float(i_time_loc_b, 0);
  kinc_g4_draw_indexed_vertices();

  kinc_g4_end(0);
  kinc_g4_swap_buffers();
}

static void load_shader(const char *filename, kinc_g4_shader_t *shader,
                        kinc_g4_shader_type_t shader_type) {
  kinc_file_reader_t file;
  kinc_file_reader_open(&file, filename, KINC_FILE_TYPE_ASSET);
  size_t data_size = kinc_file_reader_size(&file);
  uint8_t *data = allocate(data_size);
  kinc_file_reader_read(&file, data, data_size);
  kinc_file_reader_close(&file);
  kinc_g4_shader_init(shader, data, data_size, shader_type);
}

int kickstart(int argc, char **argv) {
  kinc_init("Shader", 1024, 768, NULL, NULL);
  kinc_set_update_callback(update, NULL);

  heap = (uint8_t *)malloc(HEAP_SIZE);
  assert(heap != NULL);

  kinc_g4_vertex_structure_t structure;
  kinc_g4_vertex_structure_init(&structure);
  kinc_g4_vertex_structure_add(&structure, "vertex_position",
                               KINC_G4_VERTEX_DATA_FLOAT2);
  kinc_g4_vertex_structure_add(&structure, "vertex_uv",
                               KINC_G4_VERTEX_DATA_FLOAT2);
  {
    load_shader("good.vert", &vertex_shader, KINC_G4_SHADER_TYPE_VERTEX);
    load_shader("good.frag", &fragment_shader, KINC_G4_SHADER_TYPE_FRAGMENT);

    kinc_g4_pipeline_init(&pipeline_g);
    pipeline_g.vertex_shader = &vertex_shader;
    pipeline_g.fragment_shader = &fragment_shader;
    pipeline_g.input_layout[0] = &structure;
    pipeline_g.input_layout[1] = NULL;
    pipeline_g.blend_source = KINC_G4_BLEND_SOURCE_ALPHA;
    pipeline_g.blend_destination = KINC_G4_BLEND_INV_SOURCE_ALPHA;
    pipeline_g.alpha_blend_source = KINC_G4_BLEND_SOURCE_ALPHA;
    pipeline_g.alpha_blend_destination = KINC_G4_BLEND_INV_SOURCE_ALPHA;
    kinc_g4_pipeline_compile(&pipeline_g);
    i_time_loc_g =
        kinc_g4_pipeline_get_constant_location(&pipeline_g, "i_time");
    i_resolution_loc_g =
        kinc_g4_pipeline_get_constant_location(&pipeline_g, "i_resolution");
    sg_data_loc_g =
        kinc_g4_pipeline_get_constant_location(&pipeline_g, "sg_data");
    sg_alpha_loc_g =
        kinc_g4_pipeline_get_constant_location(&pipeline_g, "sg_alpha");
    sg_mouse_loc_g =
        kinc_g4_pipeline_get_constant_location(&pipeline_g, "sg_mouse");
  }

  {
    load_shader("bad.vert", &vertex_shader, KINC_G4_SHADER_TYPE_VERTEX);
    load_shader("bad.frag", &fragment_shader, KINC_G4_SHADER_TYPE_FRAGMENT);

    kinc_g4_pipeline_init(&pipeline_b);
    pipeline_b.vertex_shader = &vertex_shader;
    pipeline_b.fragment_shader = &fragment_shader;
    pipeline_b.input_layout[0] = &structure;
    pipeline_b.input_layout[1] = NULL;
    pipeline_b.blend_source = KINC_G4_BLEND_SOURCE_ALPHA;
    pipeline_b.blend_destination = KINC_G4_BLEND_INV_SOURCE_ALPHA;
    pipeline_b.alpha_blend_source = KINC_G4_BLEND_SOURCE_ALPHA;
    pipeline_b.alpha_blend_destination = KINC_G4_BLEND_INV_SOURCE_ALPHA;
    kinc_g4_pipeline_compile(&pipeline_b);
    i_time_loc_b =
        kinc_g4_pipeline_get_constant_location(&pipeline_b, "i_time");
    i_resolution_loc_b =
        kinc_g4_pipeline_get_constant_location(&pipeline_b, "i_resolution");
    sg_data_loc_b =
        kinc_g4_pipeline_get_constant_location(&pipeline_b, "sg_data");
    sg_alpha_loc_b =
        kinc_g4_pipeline_get_constant_location(&pipeline_b, "sg_alpha");
    sg_mouse_loc_b =
        kinc_g4_pipeline_get_constant_location(&pipeline_b, "sg_mouse");
  }

  kinc_g4_vertex_buffer_init(&vertices, 3, &structure, KINC_G4_USAGE_STATIC, 0);
  {
    float *v = kinc_g4_vertex_buffer_lock_all(&vertices);
    int i = 0;

    v[i++] = -1;
    v[i++] = -1;

    v[i++] = 0.0;
    v[i++] = 0.0;

    v[i++] = 1;
    v[i++] = -1;

    v[i++] = 1.0;
    v[i++] = 0.0;

    v[i++] = -1;
    v[i++] = 1;

    v[i++] = 0.0;
    v[i++] = 1.0;

    kinc_g4_vertex_buffer_unlock_all(&vertices);
  }

  kinc_g4_index_buffer_init(&indices, 3, KINC_G4_INDEX_BUFFER_FORMAT_16BIT,
                            KINC_G4_USAGE_STATIC);
  {
    uint16_t *i = (uint16_t *)kinc_g4_index_buffer_lock_all(&indices);
    i[0] = 0;
    i[1] = 1;
    i[2] = 2;
    kinc_g4_index_buffer_unlock_all(&indices);
  }

  kinc_start();

  return 0;
}
