/* Desktop GL 2.1 / GLSL 1.20, with EXT framebuffer objects. */
#include "pub.mod/glew.mod/GL/glew.h"
#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <math.h>
#include <string.h>
#include <limits.h>

typedef struct { GLuint texture, fbo; int width,height,target,mipmapped,mip_dirty,coverage,bytes_per_pixel; GLenum upload_type,compressed_format; int block_bytes; } M2DGLFrame;
typedef struct {
    GLuint program, buffer, white;
    GLint coverage, transform, textured, source_target, source_premult, premultiply, mask;
    int width,height,clip[4];
    float sx,sy,ox,oy;
} M2DGL;
static char error[2048];
const char *m2d_gl_error(void) { return error; }
static int fail(const char *message) { snprintf(error,sizeof(error),"%s",message); return 0; }
static int checked(void) {
    GLenum e=glGetError();
    if(e==GL_NO_ERROR) return 1;
    snprintf(error,sizeof(error),"OpenGL error 0x%x",e); return 0;
}
static GLuint shader(GLenum type,const char *source) {
    GLuint s=glCreateShader(type); GLint ok=0;
    glShaderSource(s,1,&source,NULL); glCompileShader(s); glGetShaderiv(s,GL_COMPILE_STATUS,&ok);
    if(!ok) { glGetShaderInfoLog(s,sizeof(error),NULL,error); glDeleteShader(s); return 0; }
    return s;
}
void m2d_gl_close(M2DGL *c) {
    if(!c) return;
    if(c->white) glDeleteTextures(1,&c->white);
    if(c->buffer) glDeleteBuffers(1,&c->buffer);
    if(c->program) glDeleteProgram(c->program);
    free(c);
}
void *m2d_gl_open(void) {
    if(glewInit()!=GLEW_OK) { fail("GLEW initialization failed"); return NULL; }
    while(glGetError()!=GL_NO_ERROR) {}
    if(!GLEW_VERSION_2_1 || !GLEW_EXT_framebuffer_object) {
        fail("Requires desktop OpenGL 2.1 and EXT_framebuffer_object"); return NULL;
    }
    const char *vs="#version 120\nattribute vec2 position; attribute vec4 colour; attribute vec2 uv;\n"
        "uniform vec4 transform; varying vec4 tint; varying vec2 texcoord;\n"
        "void main(){ gl_Position=vec4(position*transform.xy+transform.zw,0.0,1.0); tint=colour; texcoord=uv; }";
    /* Ordinary and supplied-mip assets are straight-alpha; auto-mip assets and framebuffer
       textures are premultiplied. Only framebuffer textures are vertically
       inverted. Convert in the shader, including SOLID/SHADE, so
       target composition never needs a CPU readback or a second texture. */
	/* Alpha-only textures need explicit white RGB to match PF_A8 pixmaps. */
    const char *fs="#version 120\nuniform sampler2D image; uniform int coverage,textured,sourceTarget,sourcePremult,premultiply,mask;\n"
        "varying vec4 tint; varying vec2 texcoord;\n"
        "void main(){ vec4 c=vec4(1.0); if(textured!=0){ vec2 uv=texcoord; if(sourceTarget!=0) uv.y=1.0-uv.y;"
        "c=texture2D(image,uv); if(coverage!=0) c.rgb=vec3(1.0); if(sourcePremult!=0){ if(c.a>0.0) c.rgb/=c.a; else c.rgb=vec3(0.0); }}"
        "c*=tint; if(mask!=0 && c.a<0.5) discard; if(premultiply!=0) c.rgb*=c.a; gl_FragColor=c; }";
    GLuint v=shader(GL_VERTEX_SHADER,vs); if(!v) return NULL;
    GLuint f=shader(GL_FRAGMENT_SHADER,fs); if(!f) {glDeleteShader(v); return NULL;}
    M2DGL *c=calloc(1,sizeof(*c));
    if(!c) {glDeleteShader(v); glDeleteShader(f); fail("Out of memory"); return NULL;}
    c->program=glCreateProgram(); glAttachShader(c->program,v); glAttachShader(c->program,f);
    glBindAttribLocation(c->program,0,"position"); glBindAttribLocation(c->program,1,"colour"); glBindAttribLocation(c->program,2,"uv");
    glLinkProgram(c->program); glDeleteShader(v); glDeleteShader(f);
    GLint ok=0; glGetProgramiv(c->program,GL_LINK_STATUS,&ok);
    if(!ok) {glGetProgramInfoLog(c->program,sizeof(error),NULL,error); m2d_gl_close(c); return NULL;}
    c->transform=glGetUniformLocation(c->program,"transform");
	c->coverage=glGetUniformLocation(c->program,"coverage");
    c->textured=glGetUniformLocation(c->program,"textured");
    c->source_target=glGetUniformLocation(c->program,"sourceTarget");
    c->source_premult=glGetUniformLocation(c->program,"sourcePremult");
    c->premultiply=glGetUniformLocation(c->program,"premultiply");
    c->mask=glGetUniformLocation(c->program,"mask");
    glUseProgram(c->program); glUniform1i(glGetUniformLocation(c->program,"image"),0);
    glGenBuffers(1,&c->buffer);
    glActiveTexture(GL_TEXTURE0);glGenTextures(1,&c->white);glBindTexture(GL_TEXTURE_2D,c->white);
    const uint8_t white[4]={255,255,255,255};
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,GL_NEAREST);
    glTexImage2D(GL_TEXTURE_2D,0,GL_RGBA8,1,1,0,GL_RGBA,GL_UNSIGNED_BYTE,white);
    if(!checked()) {m2d_gl_close(c); return NULL;}
    return c;
}
void m2d_gl_destroy(M2DGLFrame *f) {
    if(!f) return;
    if(f->fbo) glDeleteFramebuffersEXT(1,&f->fbo);
    if(f->texture) glDeleteTextures(1,&f->texture);
    free(f);
}
int m2d_gl_compressed_supported(void) {
	return GLEW_EXT_texture_compression_s3tc!=0;
}
int m2d_gl_float_supported(int bits) {
	return (GLEW_ARB_texture_float||GLEW_APPLE_float_pixels||GLEW_VERSION_3_0) &&
		(bits==32 || (bits==16 && (GLEW_ARB_half_float_pixel||GLEW_APPLE_float_pixels||GLEW_VERSION_3_0)));
}
int m2d_gl_float_target_supported(int bits) {
	if(!m2d_gl_float_supported(bits)) return 0;
	return GLEW_ARB_color_buffer_float || GLEW_VERSION_3_0 ||
		(bits==16 && GLEW_APPLE_float_pixels && glewGetExtension("GL_APPLEX_color_buffer_float_16_blend"));
}
void *m2d_gl_create(int w,int h,int flags,int target,int storage,int levels) {
	int compressed=storage==4 || storage==5;
	if(compressed && (target || !levels || !m2d_gl_compressed_supported())) {
		fail("Compressed texture request unsupported");
		return NULL;
	}
	int coverage=storage==1;
	int bits=storage==2?16:storage==3?32:0;
	if(bits && ((target && !m2d_gl_float_target_supported(bits)) || ((flags&4) && !levels) || !m2d_gl_float_supported(bits))) {
		fail("Floating-point texture request unsupported");
		return NULL;
	}
    GLint max=0; glGetIntegerv(GL_MAX_TEXTURE_SIZE,&max);
    if(w<=0 || h<=0 || w>max || h>max) {fail("Texture dimensions exceed OpenGL limits");return NULL;}
    M2DGLFrame *f=calloc(1,sizeof(*f)); if(!f) {fail("Out of memory");return NULL;}
	f->coverage=coverage;
	f->compressed_format=compressed?(storage==4?GL_COMPRESSED_RGBA_S3TC_DXT1_EXT:GL_COMPRESSED_RGBA_S3TC_DXT5_EXT):0;
	f->block_bytes=compressed?(storage==4?8:16):0;
	f->bytes_per_pixel=bits?bits/2:coverage?1:4;
	f->upload_type=bits==16?GL_HALF_FLOAT_ARB:bits==32?GL_FLOAT:GL_UNSIGNED_BYTE;
    f->width=w; f->height=h; f->target=target;
	/* Only automatically generated chains use premultiplied storage. */
	f->mipmapped=(flags&4)!=0 && !levels;
	f->mip_dirty=f->mipmapped;
    glActiveTexture(GL_TEXTURE0); glGenTextures(1,&f->texture); glBindTexture(GL_TEXTURE_2D,f->texture);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MIN_FILTER,(f->mipmapped || levels>1)?
        ((flags&2)?GL_LINEAR_MIPMAP_LINEAR:GL_NEAREST_MIPMAP_NEAREST):((flags&2)?GL_LINEAR:GL_NEAREST));
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAG_FILTER,(flags&2)?GL_LINEAR:GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_S,GL_CLAMP_TO_EDGE); glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_WRAP_T,GL_CLAMP_TO_EDGE);
	int level_width=w,level_height=h;
	for(int level=0;level<(levels?levels:1);++level) {
		if(compressed) {
			size_t size=((size_t)level_width+3)/4*((level_height+3)/4)*f->block_bytes;
			if(size>INT_MAX) {
				m2d_gl_destroy(f);
				fail("Compressed texture is too large");
				return NULL;
			}
			glCompressedTexImage2D(GL_TEXTURE_2D,level,f->compressed_format,level_width,level_height,0,(GLsizei)size,NULL);
		} else {
			glTexImage2D(GL_TEXTURE_2D,level,bits==16?GL_RGBA16F_ARB:bits==32?GL_RGBA32F_ARB:coverage?GL_ALPHA8:GL_RGBA8,level_width,level_height,0,coverage?GL_ALPHA:GL_RGBA,f->upload_type,NULL);
		}
		level_width=level_width>1?level_width/2:1;
		level_height=level_height>1?level_height/2:1;
	}
	if(levels) glTexParameteri(GL_TEXTURE_2D,GL_TEXTURE_MAX_LEVEL,levels-1);
    if(target) {
        GLint old; glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT,&old);
        glGenFramebuffersEXT(1,&f->fbo); glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,f->fbo);
        glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D,f->texture,0);
        GLenum status=glCheckFramebufferStatusEXT(GL_FRAMEBUFFER_EXT);
        if(status==GL_FRAMEBUFFER_COMPLETE_EXT) {
            GLboolean scissor=glIsEnabled(GL_SCISSOR_TEST); glDisable(GL_SCISSOR_TEST);
            glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE); glClearColor(0,0,0,0); glClear(GL_COLOR_BUFFER_BIT);
            if(scissor) glEnable(GL_SCISSOR_TEST);
        }
        glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,old);
        if(status!=GL_FRAMEBUFFER_COMPLETE_EXT) {m2d_gl_destroy(f);fail("Incomplete OpenGL framebuffer");return NULL;}
    }
    if(!checked()) {m2d_gl_destroy(f); return NULL;}
    return f;
}
int m2d_gl_update_compressed(M2DGLFrame *f,int level,const uint8_t *pixels,int pitch,int w,int h) {
	size_t row_bytes=((size_t)w+3)/4*f->block_bytes;
	size_t rows=((size_t)h+3)/4;
	size_t size=row_bytes*rows;
	if(!f->compressed_format || size>INT_MAX) return fail("Invalid compressed upload");
	uint8_t *packed=NULL;
	if((size_t)pitch!=row_bytes) {
		packed=malloc(size);
		if(!packed) return fail("Out of memory");
		for(size_t row=0;row<rows;++row) memcpy(packed+row*row_bytes,pixels+row*pitch,row_bytes);
		pixels=packed;
	}
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D,f->texture);
	glCompressedTexSubImage2D(GL_TEXTURE_2D,level,0,0,w,h,f->compressed_format,(GLsizei)size,pixels);
	free(packed);
	return checked();
}
/* Supplied levels retain their straight-alpha bytes. */
int m2d_gl_update_level(M2DGLFrame *f,int level,const uint8_t *pixels,int pitch,int w,int h) {
	glActiveTexture(GL_TEXTURE0);
	glBindTexture(GL_TEXTURE_2D,f->texture);
	glPixelStorei(GL_UNPACK_ALIGNMENT,1);
	uint8_t *packed=NULL;
	if(pitch%f->bytes_per_pixel) {
		if((size_t)w>SIZE_MAX/(size_t)h/(size_t)f->bytes_per_pixel) return fail("Texture update is too large");
		size_t row_bytes=(size_t)w*f->bytes_per_pixel;
		packed=malloc(row_bytes*h);
		if(!packed) return fail("Out of memory");
		for(int row=0;row<h;++row) memcpy(packed+row*row_bytes,pixels+(size_t)row*pitch,row_bytes);
		pixels=packed;
		glPixelStorei(GL_UNPACK_ROW_LENGTH,0);
	} else {
		glPixelStorei(GL_UNPACK_ROW_LENGTH,pitch/f->bytes_per_pixel);
	}
	glTexSubImage2D(GL_TEXTURE_2D,level,0,0,w,h,f->coverage?GL_ALPHA:GL_RGBA,f->upload_type,pixels);
	glPixelStorei(GL_UNPACK_ROW_LENGTH,0);
	free(packed);
	return checked();
}
/* pixels starts at the upload region; x/y locate it in the destination. */
int m2d_gl_update(M2DGLFrame *f,const uint8_t *pixels,int pitch,int x,int y,int w,int h) {
    glActiveTexture(GL_TEXTURE0); glBindTexture(GL_TEXTURE_2D,f->texture);
    glPixelStorei(GL_UNPACK_ALIGNMENT,1);
    const uint8_t *data=pixels;
    uint8_t *converted=NULL;
    if(f->mipmapped) {
        /* Average premultiplied colours so invisible RGB cannot bleed into
           lower levels. CPU pixels and locks continue to use straight alpha. */
        if((size_t)w>SIZE_MAX/4/(size_t)h) return fail("Texture update is too large");
        converted=malloc((size_t)w*h*4);
        if(!converted) return fail("Out of memory");
        for(int row=0;row<h;++row) for(int col=0;col<w;++col) {
            const uint8_t *p=data+(size_t)row*pitch+col*4;
            uint8_t *q=converted+((size_t)row*w+col)*4;
            for(int k=0;k<3;++k) q[k]=(p[k]*p[3]+127)/255;
            q[3]=p[3];
        }
        data=converted;glPixelStorei(GL_UNPACK_ROW_LENGTH,0);
    } else if(pitch%f->bytes_per_pixel) {
		if((size_t)w>SIZE_MAX/(size_t)h/(size_t)f->bytes_per_pixel) return fail("Texture update is too large");
		size_t row_bytes=(size_t)w*f->bytes_per_pixel;
		converted=malloc(row_bytes*h);
		if(!converted) return fail("Out of memory");
		for(int row=0;row<h;++row) memcpy(converted+row*row_bytes,pixels+(size_t)row*pitch,row_bytes);
		data=converted;
		glPixelStorei(GL_UNPACK_ROW_LENGTH,0);
	} else glPixelStorei(GL_UNPACK_ROW_LENGTH,pitch/f->bytes_per_pixel);
    glTexSubImage2D(GL_TEXTURE_2D,0,x,y,w,h,f->coverage?GL_ALPHA:GL_RGBA,f->upload_type,data);
    glPixelStorei(GL_UNPACK_ROW_LENGTH,0);free(converted);
    if(!checked()) return 0;
    f->mip_dirty=f->mipmapped;
    return 1;
}
static int clampi(int x,int a,int b) {return x<a?a:x>b?b:x;}
int m2d_gl_view(M2DGL *c,M2DGLFrame *f,int width,int height,int ox,int oy,int vw,int vh,float sx,float sy,int x,int y,int w,int h) {
    c->width=width; c->height=height; c->sx=sx;c->sy=sy;c->ox=ox;c->oy=oy;
    /* Scissor edges are physical pixels, with a bottom-left GL origin.
       A zero logical extent stays empty even under fractional scaling. */
    int l=clampi(ox+(int)floorf(x*sx),ox,ox+vw), t=clampi(oy+(int)floorf(y*sy),oy,oy+vh);
    int r=w?clampi(ox+(int)ceilf((x+w)*sx),ox,ox+vw):l;
    int b=h?clampi(oy+(int)ceilf((y+h)*sy),oy,oy+vh):t;
    c->clip[0]=l;c->clip[1]=height-b;c->clip[2]=r>l?r-l:0;c->clip[3]=b>t?b-t:0;
	if(GLEW_ARB_color_buffer_float) glClampColorARB(GL_CLAMP_FRAGMENT_COLOR_ARB,GL_FIXED_ONLY_ARB);
	else if(GLEW_VERSION_3_0) glClampColor(GL_CLAMP_FRAGMENT_COLOR,GL_FIXED_ONLY);
    glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,f?f->fbo:0);
    glViewport(0,0,width,height); glEnable(GL_SCISSOR_TEST); glScissor(c->clip[0],c->clip[1],c->clip[2],c->clip[3]);
    return checked();
}
int m2d_gl_submit(M2DGL *c,M2DGLFrame *dest,M2DGLFrame *f,int blend,const float *v,int count) {
    glUseProgram(c->program); glDisable(GL_DEPTH_TEST);glDisable(GL_STENCIL_TEST);glDisable(GL_CULL_FACE);glDisable(GL_ALPHA_TEST);
    glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE);
    glUniform4f(c->transform,2*c->sx/c->width,-2*c->sy/c->height,2*c->ox/c->width-1,1-2*c->oy/c->height);
	glUniform1i(c->coverage,f&&f->coverage);
    glUniform1i(c->textured,f!=NULL);glUniform1i(c->source_target,f&&f->target);
    glUniform1i(c->source_premult,f&&(f->target||f->mipmapped));
    glUniform1i(c->mask,blend==1);glUniform1i(c->premultiply,blend==3||blend==4||(dest&&blend<=2));
    glActiveTexture(GL_TEXTURE0);glBindTexture(GL_TEXTURE_2D,f?f->texture:c->white);
    int generated=0;
    if(f && f->mip_dirty) {
        glGenerateMipmapEXT(GL_TEXTURE_2D);
        if(!checked()) return 0;
        f->mip_dirty=0;generated=1;
    }
    glBlendEquation(GL_FUNC_ADD);
    if(blend<=2) glDisable(GL_BLEND);
    else {
        glEnable(GL_BLEND);
        if(blend==3) glBlendFuncSeparate(GL_ONE,GL_ONE_MINUS_SRC_ALPHA,GL_ONE,GL_ONE_MINUS_SRC_ALPHA);
        else if(blend==4) glBlendFuncSeparate(GL_ONE,GL_ONE,GL_ZERO,GL_ONE);
        else glBlendFuncSeparate(GL_DST_COLOR,GL_ZERO,GL_ZERO,GL_ONE);
    }
    glBindBuffer(GL_ARRAY_BUFFER,c->buffer);
    glBufferData(GL_ARRAY_BUFFER,(size_t)count*8*sizeof(float),v,GL_STREAM_DRAW);
    glEnableVertexAttribArray(0);glEnableVertexAttribArray(1);glEnableVertexAttribArray(2);
    glVertexAttribPointer(0,2,GL_FLOAT,GL_FALSE,8*sizeof(float),(void*)0);
    glVertexAttribPointer(1,4,GL_FLOAT,GL_FALSE,8*sizeof(float),(void*)(2*sizeof(float)));
    glVertexAttribPointer(2,2,GL_FLOAT,GL_FALSE,8*sizeof(float),(void*)(6*sizeof(float)));
    glDrawArrays(GL_TRIANGLES,0,count);
    if(!checked()) return 0;
    if(dest) dest->mip_dirty=dest->mipmapped;
    return 1+generated;
}
int m2d_gl_clear(M2DGL *c,M2DGLFrame *target,int bars,int r,int g,int b,float a,int br,int bg,int bb) {
    glColorMask(GL_TRUE,GL_TRUE,GL_TRUE,GL_TRUE);
    if(bars) {glDisable(GL_SCISSOR_TEST);glClearColor(br/255.f,bg/255.f,bb/255.f,1);glClear(GL_COLOR_BUFFER_BIT);}
    glEnable(GL_SCISSOR_TEST);glScissor(c->clip[0],c->clip[1],c->clip[2],c->clip[3]);
    float factor=target?a:1;glClearColor(r/255.f*factor,g/255.f*factor,b/255.f*factor,a);glClear(GL_COLOR_BUFFER_BIT);
    if(!checked()) return 0;
    if(target) target->mip_dirty=target->mipmapped;
    return 1;
}
int m2d_gl_read(M2DGL *c,M2DGLFrame *f,int windowWidth,int windowHeight,int x,int y,int w,int h,uint8_t *pixels,int pitch) {
    int width=f?f->width:windowWidth,height=f?f->height:windowHeight;
    if(x<0||y<0||w>width||h>height||x>width-w||y>height-h) return fail("Readback rectangle outside surface");
    uint8_t *row=malloc((size_t)w*4);if(!row)return fail("Out of memory");
    /* Reading an arbitrary target must preserve the active drawing target. */
    GLint old;glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT,&old);glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,f?f->fbo:0);
    glPixelStorei(GL_PACK_ALIGNMENT,1);glPixelStorei(GL_PACK_ROW_LENGTH,pitch/4);
    glReadPixels(x,height-y-h,w,h,GL_RGBA,GL_UNSIGNED_BYTE,pixels);
    glPixelStorei(GL_PACK_ROW_LENGTH,0);glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,old);
    for(int yy=0;yy<h/2;++yy){uint8_t *a=pixels+(size_t)yy*pitch,*b=pixels+(size_t)(h-1-yy)*pitch;memcpy(row,a,w*4);memcpy(a,b,w*4);memcpy(b,row,w*4);}
    free(row);
    if(f) for(int yy=0;yy<h;++yy) for(int xx=0;xx<w;++xx){uint8_t *p=pixels+(size_t)yy*pitch+xx*4;int a=p[3];for(int k=0;k<3;++k)p[k]=a?clampi((p[k]*255+a/2)/a,0,255):0;}
    return checked();
}

int m2d_gl_read_float(M2DGLFrame *f,float *pixels) {
	GLint old,clamping=GL_FIXED_ONLY_ARB;
	glGetIntegerv(GL_FRAMEBUFFER_BINDING_EXT,&old);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,f->fbo);
	if(GLEW_ARB_color_buffer_float || GLEW_VERSION_3_0) {
		glGetIntegerv(GL_CLAMP_READ_COLOR_ARB,&clamping);
		if(GLEW_ARB_color_buffer_float) glClampColorARB(GL_CLAMP_READ_COLOR_ARB,GL_FALSE);
		else glClampColor(GL_CLAMP_READ_COLOR,GL_FALSE);
	}
	glPixelStorei(GL_PACK_ALIGNMENT,1);
	glPixelStorei(GL_PACK_ROW_LENGTH,0);
	glReadPixels(0,0,f->width,f->height,GL_RGBA,GL_FLOAT,pixels);
	if(GLEW_ARB_color_buffer_float) glClampColorARB(GL_CLAMP_READ_COLOR_ARB,clamping);
	else if(GLEW_VERSION_3_0) glClampColor(GL_CLAMP_READ_COLOR,clamping);
	glBindFramebufferEXT(GL_FRAMEBUFFER_EXT,old);
	if(!checked()) return 0;
	for(int y=0;y<f->height/2;++y) {
		float *top=pixels+(size_t)y*f->width*4;
		float *bottom=pixels+(size_t)(f->height-1-y)*f->width*4;
		for(size_t x=0;x<(size_t)f->width*4;++x) {
			float value=top[x];
			top[x]=bottom[x];
			bottom[x]=value;
		}
	}
	for(size_t i=0;i<(size_t)f->width*f->height;++i) {
		float *p=pixels+i*4;
		for(int channel=0;channel<3;++channel) p[channel]=p[3]!=0?p[channel]/p[3]:0;
	}
	return 1;
}
void m2d_gl_texture_size(void *context, int *width, int *height) {
	GLint limit=0;
	glGetIntegerv(GL_MAX_TEXTURE_SIZE,&limit);
	*width=*height=limit;
}

int m2d_gl_render_image(int width, int height) {
	GLint limits[2]={0,0};
	glGetIntegerv(GL_MAX_VIEWPORT_DIMS,limits);
	return width<=limits[0] && height<=limits[1];
}
