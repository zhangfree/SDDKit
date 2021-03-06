#ifndef SDD_PARSER_H
#define SDD_PARSER_H

typedef struct sdd_state_t {
	const char* name;
	const char* entries;
	const char* exits;
	const char* default_stub;
} sdd_state;

void sdd_state_init(sdd_state* state, const char* name, const char* entries, const char* exits, const char* default_stub);
void sdd_state_release(sdd_state* state);


typedef struct sdd_transition_t {
	const char* from;
	const char* to;
	const char* event;
	const char* conditions;
	const char* actions;
} sdd_transition;

sdd_transition* sdd_transition_new(const char* from, const char* to, const char* event, const char* conditions, const char* actions);
void sdd_transition_delete(sdd_transition* transition);


typedef struct sdd_array_t sdd_array;
typedef void (*sdd_parser_state_handler)(void* context, sdd_state* state);
typedef void (*sdd_parser_cluster_handler)(void* context, sdd_state* holder, sdd_array* states);
typedef void (*sdd_parser_transition_handler)(void* context, sdd_transition* transition);
typedef void (*sdd_parser_completion_handler)(void* context, sdd_state* root_state);

typedef struct sdd_parser_callback {
	void* context;
	sdd_parser_state_handler      stateHandler;
	sdd_parser_cluster_handler    clusterHandler;
	sdd_parser_transition_handler transitionHandler;
	sdd_parser_completion_handler completionHandler;
} sdd_parser_callback;

// 为了让DSL的定义更方便，这里使用了一个将括号内内容直接转成字符串的宏。这样就可以定义跨行（但是不包括换行符）的DSL内容了。例如：
// const char* dsl = sdd_language
// (
//    [A e:entry x:exit]
// );
#define sdd_language(dsl) #dsl

void sdd_parse(const char* dsl, sdd_parser_callback* callback);

#endif // SDD_PARSER_H