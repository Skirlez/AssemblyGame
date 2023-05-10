#include <iostream>
#include <chrono>
#include <thread>
#include <SDL_image.h>
#include <SDL_mixer.h>
#include <SDL.h>
#undef main
extern "C" void asmMain();
extern "C" long getTime() {  // gets the amount of time passed in nanoseconds as a number
	return std::chrono::high_resolution_clock::now().time_since_epoch().count();
}
extern "C" SDL_Rect* createSDLRect(int x, int y, int w, int h) {
	return new SDL_Rect{x, y, w, h};
}
extern "C" void deleteSDLRect(SDL_Rect* rect) {
	delete rect;
}
extern "C" int distanceBetweenPoints(int x1, int y1, int x2, int y2) {
	return static_cast<int>(sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2)));
}
int main(int argc, char* argv[]) {
	asmMain();
	return 0;
}